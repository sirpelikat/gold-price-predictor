import pandas as pd
from sklearn.linear_model import LinearRegression
from data_fetcher import get_historical_gold_data
from datetime import timedelta

def train_and_predict(days_to_predict=7):
    # Fetch last 60 trading days for the trend
    df = get_historical_gold_data(days=60)
    
    if df.empty:
        return []

    # Prepare data for simple linear regression (predicting trend based on time)
    df = df.dropna(subset=['Close'])
    # Make a copy to avoid SettingWithCopyWarning if it was a slice
    df = df.copy() 
    df['DayIndex'] = range(len(df))
    
    X = df[['DayIndex']]
    y = df['Close']
    
    model = LinearRegression()
    model.fit(X, y)
    
    # Predict future
    last_day = df['DayIndex'].iloc[-1]
    # The index of history() is usually a tz-aware datetime
    last_date = df.index[-1]
    
    future_X = pd.DataFrame({'DayIndex': range(last_day + 1, last_day + 1 + days_to_predict)})
    predicted_prices = model.predict(future_X)
    
    predictions = []
    for i, price in enumerate(predicted_prices):
        val = float(price)
        target_date = last_date + timedelta(days=i+1)
        predictions.append({
            "date": target_date.strftime('%Y-%m-%d'),
            "price": val
        })
        
    return predictions
