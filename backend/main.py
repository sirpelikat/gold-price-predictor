from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from data_fetcher import get_current_gold_price, get_historical_gold_data
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
    price = get_current_gold_price()
    # price might be a pandas float/series, ensure we extract the float
    if hasattr(price, "item"):
        price = price.item()
    return {"current_price": float(price) if price else None}

@app.get("/api/historical")
def historical(days: int = 30):
    df = get_historical_gold_data(days=days)
    if df.empty:
        return {"data": []}
        
    # Convert index (Dates) to string for JSON serialization
    df = df.reset_index()
    
    historical_data = []
    for index, row in df.iterrows():
        close_val = row['Close']
        if hasattr(close_val, "item"):
            close_val = close_val.item()
            
        historical_data.append({
            "date": row['Date'].strftime('%Y-%m-%d'),
            "price": float(close_val)
        })
        
    return {"data": historical_data}

@app.get("/api/prediction")
def prediction():
    preds = train_and_predict(days_to_predict=7)
    return {"predictions": preds}
