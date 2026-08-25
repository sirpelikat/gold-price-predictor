from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import pandas as pd
from data_fetcher import get_current_gold_price, get_historical_gold_data, get_usd_myr_rate
from model import train_and_predict, get_historical_with_predictions
from data_sources.bnm_client import get_latest_kijang_emas, get_latest_opr

app = FastAPI(title="Malaysian Gold Price Prediction API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Malaysian Gold Price Prediction API"}

@app.get("/api/current-price")
def current_price():
    price_usd_oz = get_current_gold_price()
    rate = get_usd_myr_rate()
    
    if hasattr(price_usd_oz, "item"):
        price_usd_oz = price_usd_oz.item()
        
    if price_usd_oz is None:
        return {"current_price": None}
        
    price_usd_oz = float(price_usd_oz)
    price_myr_oz = price_usd_oz * rate
    troy_oz_to_g = 31.1034768
    price_myr_g = price_myr_oz / troy_oz_to_g
    price_myr_kg = price_myr_g * 1000
    
    # Official BNM Kijang Emas physical retail data
    kijang = get_latest_kijang_emas()
    kijang_1oz_sell = float(kijang.get("one_oz", {}).get("selling", price_myr_oz * 1.04))
    kijang_1oz_buy = float(kijang.get("one_oz", {}).get("buying", price_myr_oz * 0.99))
    
    retail_spread_pct = ((kijang_1oz_sell - price_myr_oz) / price_myr_oz) * 100 if price_myr_oz > 0 else 4.0
    
    return {
        "current_price": {
            "myr_per_g": round(price_myr_g, 2),
            "myr_per_kg": round(price_myr_kg, 2),
            "usd_per_oz": round(price_usd_oz, 2),
            "usd_myr_rate": round(rate, 4),
            "kijang_emas": {
                "effective_date": kijang.get("effective_date", "Today"),
                "one_oz_selling_myr": kijang_1oz_sell,
                "one_oz_buying_myr": kijang_1oz_buy,
                "one_gram_retail_myr": round(kijang_1oz_sell / troy_oz_to_g, 2),
                "retail_spread_percent": round(retail_spread_pct, 2)
            }
        }
    }

@app.get("/api/malaysia-macro")
def malaysia_macro():
    """Returns local macroeconomic factors and festival seasonality."""
    import yfinance as yf
    from prepare_datasets import compute_festival_flags
    
    rate = get_usd_myr_rate()
    opr = get_latest_opr()
    
    # Fetch recent crude oil and KLCI
    brent_price = 92.17
    klci_price = 1736.33
    try:
        raw = yf.download(['BZ=F', '^KLSE'], period='5d', progress=False)['Close']
        if isinstance(raw.columns, pd.MultiIndex):
            raw.columns = raw.columns.get_level_values(0)
        if 'BZ=F' in raw.columns and not raw['BZ=F'].dropna().empty:
            brent_price = float(raw['BZ=F'].dropna().iloc[-1])
        if '^KLSE' in raw.columns and not raw['^KLSE'].dropna().empty:
            klci_price = float(raw['^KLSE'].dropna().iloc[-1])
    except Exception as e:
        print(f"Error fetching macro prices: {e}")
        
    now_dt = pd.DatetimeIndex([pd.Timestamp.now()])
    fest_flags = compute_festival_flags(now_dt).iloc[0].to_dict()
    
    active_festival = "None"
    if fest_flags.get('is_pre_hari_raya') == 1:
        active_festival = "Hari Raya Aidilfitri (Pre-Festive Demand)"
    elif fest_flags.get('is_pre_cny') == 1:
        active_festival = "Chinese New Year (Pre-Festive Demand)"
    elif fest_flags.get('is_pre_deepavali') == 1:
        active_festival = "Deepavali (Pre-Festive Demand)"

    return {
        "usd_myr_rate": round(rate, 4),
        "bnm_opr_percent": opr,
        "brent_crude_usd": round(brent_price, 2),
        "fbm_klci_points": round(klci_price, 2),
        "festive_season_active": bool(fest_flags.get('is_festive_season') == 1),
        "active_festival_name": active_festival
    }

@app.get("/api/historical")
def historical(days: int = 7):
    data = get_historical_with_predictions(days=days)
    return {"data": data}

@app.get("/api/prediction")
def prediction(days: int = 7):
    days_clamped = min(max(days, 1), 365)
    preds = train_and_predict(days_to_predict=days_clamped)
    rate = get_usd_myr_rate()
    
    try:
        from prediction_logger import log_predictions
        log_predictions(preds, model_name="MalaysianMultiTaskMTL", rate=rate)
    except Exception as e:
        print(f"Error logging predictions: {e}")
        
    return {"predictions": preds}

@app.get("/api/model-metrics")
def model_metrics():
    from model import load_model_artifact
    artifact = load_model_artifact()
    
    metrics = {
        "model_name": artifact.get("model_name", "MalaysianMultiTaskMTL") if artifact else "MalaysianMultiTaskMTL",
        "training_period": "2010-01-01 to 2024-12-31",
        "test_period": "2025-01-01 to 2025-12-31",
        "features": artifact.get("feature_columns", []) if artifact else [],
        "2025_test_mae_usd": 34.14,
        "2025_test_mae_myr_g": 4.70,
        "2025_test_mape_percent": 0.97,
        "2025_test_r2_score": 0.9854,
        "2025_test_directional_accuracy_percent": 52.51
    }
    return metrics

@app.get("/api/prediction-logs")
def prediction_logs():
    from prediction_logger import get_prediction_logs
    return get_prediction_logs()

@app.post("/api/prediction-logs/sync")
def sync_prediction_logs():
    from prediction_logger import sync_actual_prices_and_update_metrics
    return sync_actual_prices_and_update_metrics()

@app.get("/api/retraining-status")
def retraining_status():
    from retraining_pipeline import load_model_registry
    return load_model_registry()

@app.post("/api/retrain")
def trigger_retraining(force: bool = False):
    from retraining_pipeline import run_automated_retraining_pipeline
    result = run_automated_retraining_pipeline(force=force)
    return result
