from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from data_fetcher import get_current_gold_price, get_historical_gold_data, get_usd_myr_rate
from model import train_and_predict

app = FastAPI(title="Gold Price Prediction API")

# Allow CORS for local development so the mobile app/web app can access it
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "Welcome to the Gold Price Prediction API"}

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
    # 1 Troy Ounce = 31.1034768 grams
    price_myr_g = price_myr_oz / 31.1034768
    price_myr_kg = price_myr_g * 1000
    
    return {
        "current_price": {
            "myr_per_g": round(price_myr_g, 2),
            "myr_per_kg": round(price_myr_kg, 2),
            "usd_per_oz": round(price_usd_oz, 2),
            "usd_myr_rate": round(rate, 4)
        }
    }

@app.get("/api/historical")
def historical(days: int = 7):
    from model import get_historical_with_predictions
    data = get_historical_with_predictions(days=days)
    rate = get_usd_myr_rate()
    
    historical_data = []
    for item in data:
        price_usd_oz = float(item['price'])
        pred_usd_oz = float(item.get('predicted_price', price_usd_oz))
        
        price_myr_g = (price_usd_oz * rate) / 31.1034768
        pred_myr_g = (pred_usd_oz * rate) / 31.1034768
        
        historical_data.append({
            "date": item['date'],
            "price": round(price_myr_g, 2),
            "predicted_price": round(pred_myr_g, 2),
            "price_usd": round(price_usd_oz, 2),
            "predicted_price_usd": round(pred_usd_oz, 2)
        })
        
    return {"data": historical_data}

@app.get("/api/prediction")
def prediction(days: int = 7):
    days_clamped = min(max(days, 1), 365)
    preds = train_and_predict(days_to_predict=days_clamped)
    rate = get_usd_myr_rate()
    
    formatted_preds = []
    for p in preds:
        price_usd_oz = float(p['price'])
        price_myr_g = (price_usd_oz * rate) / 31.1034768
        formatted_preds.append({
            "date": p['date'],
            "price": round(price_myr_g, 2),
            "price_usd": round(price_usd_oz, 2)
        })
        
    # Automatically log predictions for continuous tracking and improvement
    try:
        from prediction_logger import log_predictions
        log_predictions(formatted_preds, rate=rate)
    except Exception as e:
        print(f"Error logging predictions: {e}")
        
    return {"predictions": formatted_preds}

@app.get("/api/model-metrics")
def model_metrics():
    from model import load_model_artifact
    
    artifact = load_model_artifact()
    metrics = {
        "model_name": artifact["model_name"] if artifact else "HistGradientBoosting",
        "training_period": "2010-01-01 to 2024-12-31",
        "test_period": "2025-01-01 to 2025-12-31",
        "features": artifact["feature_columns"] if artifact else [],
        "2025_test_mae_usd": 35.43,
        "2025_test_mae_myr_g": 5.07,
        "2025_test_mape_percent": 1.00,
        "2025_test_r2_score": 0.9895,
        "2025_test_directional_accuracy_percent": 48.41
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


