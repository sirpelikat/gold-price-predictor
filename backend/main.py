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
            "myr_per_g": price_myr_g,
            "myr_per_kg": price_myr_kg
        }
    }

@app.get("/api/historical")
def historical(days: int = 30):
    df = get_historical_gold_data(days=days)
    rate = get_usd_myr_rate()
    
    if df.empty:
        return {"data": []}
        
    # Convert index (Dates) to string for JSON serialization
    df = df.reset_index()
    
    historical_data = []
    for index, row in df.iterrows():
        close_val = row['Close']
        if hasattr(close_val, "item"):
            close_val = close_val.item()
            
        price_usd_oz = float(close_val)
        price_myr_g = (price_usd_oz * rate) / 31.1034768
            
        historical_data.append({
            "date": row['Date'].strftime('%Y-%m-%d'),
            "price": price_myr_g
        })
        
    return {"data": historical_data}

@app.get("/api/prediction")
def prediction():
    preds = train_and_predict(days_to_predict=7)
    rate = get_usd_myr_rate()
    
    for p in preds:
        price_usd_oz = p['price']
        price_myr_g = (price_usd_oz * rate) / 31.1034768
        p['price'] = price_myr_g
        
    return {"predictions": preds}
