import pandas as pd
from sklearn.linear_model import LinearRegression
from data_fetcher import get_historical_gold_data
from datetime import timedelta

def train_and_predict(days_to_predict=7):
    # Fetch last 14 trading days to capture short-term momentum matching app trend
    df = get_historical_gold_data(days=14)
    
    if df.empty:
        return []

    # Prepare data for short-term linear regression
    df = df.dropna(subset=['Close']).copy()
    df['DayIndex'] = list(range(len(df)))
    
    X = df[['DayIndex']]
    y = df['Close']
    
    model = LinearRegression()
    model.fit(X, y)
    
    # Anchor future predictions to smoothly continue from the latest closing price
    last_date = df.index[-1]
    last_price = float(df['Close'].iloc[-1])
    slope = float(model.coef_[0])
    
    predictions = []
    for i in range(days_to_predict):
        val = last_price + (i + 1) * slope
        target_date = last_date + timedelta(days=i+1)
        predictions.append({
            "date": target_date.strftime('%Y-%m-%d'),
            "price": val
        })
        
    return predictions
