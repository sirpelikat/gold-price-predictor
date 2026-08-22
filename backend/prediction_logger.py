import os
import json
import pandas as pd
import numpy as np
from datetime import datetime, timezone
import yfinance as yf

LOGS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs")
PREDICTIONS_LOG_FILE = os.path.join(LOGS_DIR, "prediction_history.csv")
METRICS_LOG_FILE = os.path.join(LOGS_DIR, "model_performance_log.json")

def ensure_logs_dir():
    os.makedirs(LOGS_DIR, exist_ok=True)

def log_predictions(predictions: list, model_name: str = "HistGradientBoosting", rate: float = 4.45):
    """
    Logs generated predictions to prediction_history.csv.
    Avoids duplicate entries for the same target date and model version.
    """
    ensure_logs_dir()
    now_str = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    
    rows = []
    for p in predictions:
        price_myr_g = p['price']
        price_usd_oz = (price_myr_g * 31.1034768) / rate
        
        rows.append({
            "logged_at": now_str,
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
        # Avoid exact duplicate target_date + model_name on the same day
        combined_df = pd.concat([existing_df, new_df], ignore_index=True)
        combined_df.drop_duplicates(subset=['target_date', 'model_name'], keep='last', inplace=True)
    else:
        combined_df = new_df
        
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
        
    usd_to_myr = 4.45
    troy_oz_to_g = 31.1034768
    updated_count = 0
    
    for idx, row in df.iterrows():
        target_date = str(row['target_date'])
        if target_date in actuals_df.index:
            actual_usd = float(actuals_df.loc[target_date, 'Close'])
            actual_myr = (actual_usd * usd_to_myr) / troy_oz_to_g
            pred_usd = float(row['predicted_price_usd'])
            
            err_usd = abs(actual_usd - pred_usd)
            pct_err = (err_usd / actual_usd) * 100
            
            df.at[idx, 'actual_price_usd'] = round(actual_usd, 2)
            df.at[idx, 'actual_price_myr_g'] = round(actual_myr, 2)
            df.at[idx, 'error_usd'] = round(err_usd, 2)
            df.at[idx, 'percentage_error'] = round(pct_err, 2)
            updated_count += 1
            
    df.to_csv(PREDICTIONS_LOG_FILE, index=False)
    metrics_summary = _recalculate_metrics(df)
    return {"status": "success", "records_updated": updated_count, "metrics": metrics_summary}

def _recalculate_metrics(df: pd.DataFrame):
    usd_to_myr = 4.45
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
            "total_predictions_logged": len(df),
            "total_evaluated_days": len(evaluated_rows),
            "overall_accuracy_percentage": overall_acc,
            "mean_absolute_error_usd": round(mae_usd, 2),
            "mean_absolute_error_myr_g": round((mae_usd * usd_to_myr) / troy_oz_to_g, 2),
            "mape_percentage": round(mape, 2),
            "worst_day": {
                "target_date": worst['target_date'],
                "predicted_price_usd": worst['predicted_price_usd'],
                "actual_price_usd": worst['actual_price_usd'],
                "percentage_error": worst['percentage_error']
            },
            "best_day": {
                "target_date": best['target_date'],
                "predicted_price_usd": best['predicted_price_usd'],
                "actual_price_usd": best['actual_price_usd'],
                "percentage_error": best['percentage_error']
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
    
    usd_to_myr = 4.45
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
    """Returns all logged predictions and current summary statistics, auto-syncing if needed."""
    ensure_logs_dir()
    if not os.path.exists(PREDICTIONS_LOG_FILE):
        backfill_all_history()
    else:
        # Quick sync to ensure latest day is updated
        try:
            sync_actual_prices_and_update_metrics()
        except Exception as e:
            print(f"Auto-sync on get_prediction_logs failed: {e}")
            
    logs = []
    if os.path.exists(PREDICTIONS_LOG_FILE):
        df = pd.read_csv(PREDICTIONS_LOG_FILE)
        # Sort by target_date descending so newest is first
        df = df.sort_values(by='target_date', ascending=False)
        logs = df.to_dict(orient='records')
        
    summary = {}
    if os.path.exists(METRICS_LOG_FILE):
        with open(METRICS_LOG_FILE, 'r') as f:
            summary = json.load(f)
            
    return {
        "summary": summary,
        "logs": logs
    }

if __name__ == "__main__":
    print("Testing backfill and sync...")
    backfill_all_history()
    print("Done!")
