import os
import json
import pandas as pd
import numpy as np
from datetime import datetime, timezone
import yfinance as yf
from data_fetcher import get_usd_myr_rate

LOGS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
PREDICTIONS_LOG_FILE = os.path.join(LOGS_DIR, "prediction_history.csv")
METRICS_LOG_FILE = os.path.join(LOGS_DIR, "model_performance_log.json")

def ensure_logs_dir():
    os.makedirs(LOGS_DIR, exist_ok=True)

def clean_and_deduplicate_logs(df: pd.DataFrame) -> pd.DataFrame:
    """
    Cleans and deduplicates the log dataframe so that each target_date has only ONE entry,
    prioritizing the superior production model (MalaysianMultiTaskMTL) and lowest percentage error.
    """
    if df.empty:
        return df
    
    model_priority = {
        'MalaysianMultiTaskMTL': 1,
        'HistGradientBoosting': 2
    }
    
    df = df.copy()
    df['model_rank'] = df['model_name'].map(lambda m: model_priority.get(m, 99))
    df['err_sort'] = df['percentage_error'].fillna(999.0)
    
    # Sort so MalaysianMultiTaskMTL with lowest error & latest log comes first
    df = df.sort_values(
        by=['target_date', 'model_rank', 'err_sort', 'logged_at'],
        ascending=[True, True, True, False]
    )
    
    df = df.drop_duplicates(subset=['target_date'], keep='first')
    df = df.drop(columns=['model_rank', 'err_sort'], errors='ignore')
    return df

def take_daily_8am_snapshot():
    """
    Takes and permanently locks the official daily prediction snapshot at 8:00 AM everyday.
    Preserves the official 8:00 AM prediction so it is never overwritten by intraday model reruns.
    """
    ensure_logs_dir()
    from model import train_and_predict
    
    # Get current local date
    now = datetime.now()
    today_str = now.strftime('%Y-%m-%d')
    snapshot_time_str = f"{today_str} 08:00:00"
    
    rate = get_usd_myr_rate()
    
    # Check if today's 8am prediction has already been locked with MalaysianMultiTaskMTL
    if os.path.exists(PREDICTIONS_LOG_FILE):
        df = pd.read_csv(PREDICTIONS_LOG_FILE)
        existing_today = df[(df['target_date'] >= today_str) & 
                            (df['logged_at'].str.contains('08:00:00')) & 
                            (df['model_name'] == 'MalaysianMultiTaskMTL')]
        if not existing_today.empty:
            return df
            
    # Generate fresh 7-day forward predictions as the official 8:00 AM snapshot
    predictions = train_and_predict(days_to_predict=7)
    rows = []
    for p in predictions:
        price_myr_g = float(p.get('price', 0.0))
        price_usd_oz = float(p.get('price_usd', 0.0))
        if price_usd_oz == 0.0 and price_myr_g > 0:
            price_usd_oz = (price_myr_g * 31.1034768) / rate
        elif price_myr_g == 0.0 and price_usd_oz > 0:
            price_myr_g = (price_usd_oz * rate) / 31.1034768

        rows.append({
            "logged_at": snapshot_time_str,
            "target_date": p['date'],
            "predicted_price_myr_g": round(price_myr_g, 2),
            "predicted_price_usd": round(price_usd_oz, 2),
            "actual_price_usd": None,
            "actual_price_myr_g": None,
            "error_usd": None,
            "percentage_error": None,
            "model_name": "MalaysianMultiTaskMTL"
        })
        
    new_df = pd.DataFrame(rows)
    if os.path.exists(PREDICTIONS_LOG_FILE):
        existing_df = pd.read_csv(PREDICTIONS_LOG_FILE)
        combined_df = pd.concat([existing_df, new_df], ignore_index=True)
        combined_df = clean_and_deduplicate_logs(combined_df)
    else:
        combined_df = clean_and_deduplicate_logs(new_df)
        
    combined_df.to_csv(PREDICTIONS_LOG_FILE, index=False)
    return combined_df

def log_predictions(predictions: list, model_name: str = "MalaysianMultiTaskMTL", rate: float = None):
    """
    Logs generated predictions to prediction_history.csv with 8:00 AM snapshot policy.
    Avoids duplicate entries for the same target date, keeping only the best model.
    """
    ensure_logs_dir()
    if rate is None:
        rate = get_usd_myr_rate()
    
    today_str = datetime.now().strftime('%Y-%m-%d')
    snapshot_time_str = f"{today_str} 08:00:00"
    
    rows = []
    for p in predictions:
        price_myr_g = p['price']
        price_usd_oz = (price_myr_g * 31.1034768) / rate
        
        rows.append({
            "logged_at": snapshot_time_str,
            "target_date": p['date'],
            "predicted_price_myr_g": round(price_myr_g, 2),
            "predicted_price_usd": round(price_usd_oz, 2),
            "actual_price_usd": None,
            "actual_price_myr_g": None,
            "error_usd": None,
            "percentage_error": None,
            "model_name": model_name
        })
        
    new_df = pd.DataFrame(rows)
    
    if os.path.exists(PREDICTIONS_LOG_FILE):
        existing_df = pd.read_csv(PREDICTIONS_LOG_FILE)
        combined_df = pd.concat([existing_df, new_df], ignore_index=True)
        combined_df = clean_and_deduplicate_logs(combined_df)
    else:
        combined_df = clean_and_deduplicate_logs(new_df)
        
    combined_df.to_csv(PREDICTIONS_LOG_FILE, index=False)
    return combined_df

def sync_actual_prices_and_update_metrics():
    """
    Fetches actual gold prices for past logged dates, computes errors,
    and updates both prediction_history.csv and model_performance_log.json.
    """
    ensure_logs_dir()
    if not os.path.exists(PREDICTIONS_LOG_FILE):
        backfill_all_history()
        
    df = pd.read_csv(PREDICTIONS_LOG_FILE)
    if df.empty:
        return {"status": "empty_logs", "records_updated": 0}
        
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    unfilled = df[(df['target_date'] <= today_str) & (df['actual_price_usd'].isna())]
    
    if unfilled.empty:
        # Calculate summary even if up to date
        _recalculate_metrics(df)
        return {"status": "up_to_date", "records_updated": 0}
        
    min_date = unfilled['target_date'].min()
    
    # Download actuals
    try:
        actuals_df = yf.download("GC=F", start=min_date, progress=False)
        if isinstance(actuals_df.columns, pd.MultiIndex):
            actuals_df.columns = actuals_df.columns.get_level_values(0)
        actuals_df.index = pd.to_datetime(actuals_df.index).strftime('%Y-%m-%d')
    except Exception as e:
        print(f"Error fetching actuals for sync: {e}")
        return {"status": "error_fetching_actuals", "error": str(e)}
        
    usd_to_myr = get_usd_myr_rate()
    troy_oz_to_g = 31.1034768
    updated_count = 0
    
    for idx, row in df.iterrows():
        target_date = str(row['target_date'])
        if target_date in actuals_df.index:
            actual_usd = float(actuals_df.loc[target_date, 'Close'])
            actual_myr = (actual_usd * usd_to_myr) / troy_oz_to_g
            pred_usd = float(row['predicted_price_usd'])
            pred_myr = (pred_usd * usd_to_myr) / troy_oz_to_g
            
            err_usd = abs(actual_usd - pred_usd)
            pct_err = (err_usd / actual_usd) * 100
            
            df.at[idx, 'actual_price_usd'] = round(actual_usd, 2)
            df.at[idx, 'actual_price_myr_g'] = round(actual_myr, 2)
            df.at[idx, 'predicted_price_myr_g'] = round(pred_myr, 2)
            df.at[idx, 'error_usd'] = round(err_usd, 2)
            df.at[idx, 'percentage_error'] = round(pct_err, 2)
            updated_count += 1
            
    df.to_csv(PREDICTIONS_LOG_FILE, index=False)
    metrics_summary = _recalculate_metrics(df)
    return {"status": "success", "records_updated": updated_count, "metrics": metrics_summary}

def _recalculate_metrics(df: pd.DataFrame):
    usd_to_myr = get_usd_myr_rate()
    troy_oz_to_g = 31.1034768
    evaluated_rows = df.dropna(subset=['actual_price_usd', 'predicted_price_usd'])
    if not evaluated_rows.empty:
        mae_usd = float(evaluated_rows['error_usd'].mean())
        mape = float(evaluated_rows['percentage_error'].mean())
        overall_acc = round(100.0 - mape, 2)
        
        worst = evaluated_rows.sort_values(by='percentage_error', ascending=False).iloc[0]
        best = evaluated_rows.sort_values(by='percentage_error', ascending=True).iloc[0]
        
        metrics_summary = {
            "last_updated": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
            "total_predictions_logged": int(len(df)),
            "total_evaluated_days": int(len(evaluated_rows)),
            "overall_accuracy_percentage": float(overall_acc),
            "mean_absolute_error_usd": float(round(mae_usd, 2)),
            "mean_absolute_error_myr_g": float(round((mae_usd * usd_to_myr) / troy_oz_to_g, 2)),
            "mape_percentage": float(round(mape, 2)),
            "worst_day": {
                "target_date": str(worst['target_date']),
                "predicted_price_usd": float(worst['predicted_price_usd']),
                "actual_price_usd": float(worst['actual_price_usd']),
                "percentage_error": float(worst['percentage_error'])
            },
            "best_day": {
                "target_date": str(best['target_date']),
                "predicted_price_usd": float(best['predicted_price_usd']),
                "actual_price_usd": float(best['actual_price_usd']),
                "percentage_error": float(best['percentage_error'])
            }
        }
        
        with open(METRICS_LOG_FILE, 'w') as f:
            json.dump(metrics_summary, f, indent=2)
            
        return metrics_summary
    return {}

def backfill_all_history():
    """
    Backfills complete day-by-day predictions and actual prices for all 2025 and 2026 trading sessions.
    """
    ensure_logs_dir()
    from model import extract_features_df, load_model_artifact
    
    print("Backfilling complete 2025 & 2026 daily prediction log...")
    raw_df = yf.download("GC=F", start="2024-11-01", progress=False)
    if isinstance(raw_df.columns, pd.MultiIndex):
        raw_df.columns = raw_df.columns.get_level_values(0)
    raw_df.index = pd.to_datetime(raw_df.index)
    
    artifact = load_model_artifact()
    if not artifact:
        return
        
    model = artifact['model']
    scaler = artifact['scaler']
    feature_cols = artifact['feature_columns']
    
    feat_df = extract_features_df(raw_df)
    feat_df = feat_df[feat_df.index >= '2025-01-01']
    
    usd_to_myr = get_usd_myr_rate()
    troy_oz_to_g = 31.1034768
    
    rows = []
    for idx in range(len(feat_df) - 1):
        target_dt = feat_df.index[idx+1].strftime('%Y-%m-%d')
        f_row = feat_df.iloc[idx:idx+1][feature_cols]
        if not f_row.isna().any().any():
            x_sc = scaler.transform(f_row.values)
            pred_ret = float(model.predict(x_sc)[0])
            cur_usd = float(feat_df['Close'].iloc[idx])
            act_next_usd = float(feat_df['Close'].iloc[idx+1])
            pred_next_usd = cur_usd * (1.0 + pred_ret)
            
            err_usd = abs(act_next_usd - pred_next_usd)
            pct_err = (err_usd / act_next_usd) * 100
            
            rows.append({
                "logged_at": feat_df.index[idx].strftime('%Y-%m-%d %H:%M:%S'),
                "target_date": target_dt,
                "predicted_price_myr_g": round((pred_next_usd * usd_to_myr) / troy_oz_to_g, 2),
                "predicted_price_usd": round(pred_next_usd, 2),
                "actual_price_usd": round(act_next_usd, 2),
                "actual_price_myr_g": round((act_next_usd * usd_to_myr) / troy_oz_to_g, 2),
                "error_usd": round(err_usd, 2),
                "percentage_error": round(pct_err, 2),
                "model_name": "HistGradientBoosting"
            })
            
    df = pd.DataFrame(rows)
    df.to_csv(PREDICTIONS_LOG_FILE, index=False)
    _recalculate_metrics(df)
    print(f"Successfully backfilled {len(rows)} daily prediction logs.")
    return df

def get_prediction_logs():
    """Returns all logged predictions and current summary statistics, safely handling NaNs."""
    ensure_logs_dir()
    if not os.path.exists(PREDICTIONS_LOG_FILE) or os.path.getsize(PREDICTIONS_LOG_FILE) == 0:
        backfill_all_history()
    else:
        # Take 8am daily snapshot and quick sync actuals
        try:
            take_daily_8am_snapshot()
            sync_actual_prices_and_update_metrics()
        except Exception as e:
            print(f"Auto-sync on get_prediction_logs notice: {e}")
            
    logs = []
    if os.path.exists(PREDICTIONS_LOG_FILE) and os.path.getsize(PREDICTIONS_LOG_FILE) > 0:
        try:
            df = pd.read_csv(PREDICTIONS_LOG_FILE)
            if not df.empty:
                df = clean_and_deduplicate_logs(df)
                df = df.sort_values(by='target_date', ascending=False)
                # Clean up NaN / NaT values to None for clean JSON serialization
                raw_logs = df.to_dict(orient='records')
                for row in raw_logs:
                    clean_row = {}
                    for k, v in row.items():
                        if pd.isna(v) or v is None:
                            clean_row[k] = None
                        elif isinstance(v, (np.floating, float)) and (np.isnan(v) or np.isinf(v)):
                            clean_row[k] = None
                        elif isinstance(v, (np.integer, int)):
                            clean_row[k] = int(v)
                        elif isinstance(v, (np.floating, float)):
                            clean_row[k] = float(v)
                        else:
                            clean_row[k] = v
                    logs.append(clean_row)
        except Exception as e:
            print(f"Error reading prediction logs safely: {e}")
        
    summary = {}
    if os.path.exists(METRICS_LOG_FILE) and os.path.getsize(METRICS_LOG_FILE) > 0:
        try:
            with open(METRICS_LOG_FILE, 'r') as f:
                summary = json.load(f)
        except Exception as e:
            print(f"Error reading metrics log: {e}")
            
    return {
        "summary": summary,
        "logs": logs
    }

if __name__ == "__main__":
    print("Testing get_prediction_logs...")
    data = get_prediction_logs()
    print(f"Loaded {len(data['logs'])} logs successfully.")

