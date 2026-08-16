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
        return {"status": "no_logs_found", "records_updated": 0}
        
    df = pd.read_csv(PREDICTIONS_LOG_FILE)
    if df.empty:
        return {"status": "empty_logs", "records_updated": 0}
        
    # Find records with past target_dates that haven't been backfilled
    today_str = datetime.now(timezone.utc).strftime('%Y-%m-%d')
    unfilled = df[df['target_date'] <= today_str]
    
    if unfilled.empty:
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
    
    # Calculate cumulative accuracy metrics
    evaluated_rows = df.dropna(subset=['actual_price_usd', 'predicted_price_usd'])
    if not evaluated_rows.empty:
        mae_usd = float(evaluated_rows['error_usd'].mean())
        mape = float(evaluated_rows['percentage_error'].mean())
        overall_acc = round(100.0 - mape, 2)
        
        metrics_summary = {
            "last_updated": datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
            "total_predictions_logged": len(df),
            "total_evaluated_days": len(evaluated_rows),
            "overall_accuracy_percentage": overall_acc,
            "mean_absolute_error_usd": round(mae_usd, 2),
            "mean_absolute_error_myr_g": round((mae_usd * usd_to_myr) / troy_oz_to_g, 2),
            "mape_percentage": round(mape, 2),
            "worst_day": evaluated_rows.sort_values(by='percentage_error', ascending=False).iloc[0][['target_date', 'predicted_price_usd', 'actual_price_usd', 'percentage_error']].to_dict(),
            "best_day": evaluated_rows.sort_values(by='percentage_error', ascending=True).iloc[0][['target_date', 'predicted_price_usd', 'actual_price_usd', 'percentage_error']].to_dict()
        }
        
        with open(METRICS_LOG_FILE, 'w') as f:
            json.dump(metrics_summary, f, indent=2)
            
        return {"status": "success", "records_updated": updated_count, "metrics": metrics_summary}
        
    return {"status": "success", "records_updated": updated_count}

def get_prediction_logs():
    """Returns all logged predictions and current summary statistics."""
    ensure_logs_dir()
    logs = []
    if os.path.exists(PREDICTIONS_LOG_FILE):
        df = pd.read_csv(PREDICTIONS_LOG_FILE)
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
    print("Testing sync and metrics logger...")
    # Import historical 2025 and 2026 logs if empty
    ensure_logs_dir()
    if not os.path.exists(PREDICTIONS_LOG_FILE):
        # Prepopulate with 2025 and 2026 evaluation runs
        eval_2025 = pd.read_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "eval_results_2025.csv"))
        rows = []
        usd_to_myr = 4.45
        troy_oz_to_g = 31.1034768
        for _, r in eval_2025.iterrows():
            pred_usd = float(r['predicted_next_close'])
            act_usd = float(r['actual_next_close'])
            err = float(r['absolute_error'])
            pct = float(r['percentage_error'])
            rows.append({
                "logged_at": "2025-Benchmark",
                "target_date": r['Date'],
                "predicted_price_myr_g": round((pred_usd * usd_to_myr) / troy_oz_to_g, 2),
                "predicted_price_usd": round(pred_usd, 2),
                "actual_price_usd": round(act_usd, 2),
                "actual_price_myr_g": round((act_usd * usd_to_myr) / troy_oz_to_g, 2),
                "error_usd": round(err, 2),
                "percentage_error": round(pct, 2),
                "model_name": "HistGradientBoosting"
            })
        pd.DataFrame(rows).to_csv(PREDICTIONS_LOG_FILE, index=False)
        print(f"Prepopulated {len(rows)} 2025 evaluation history logs.")
        
    res = sync_actual_prices_and_update_metrics()
    print("Sync output:", res)
