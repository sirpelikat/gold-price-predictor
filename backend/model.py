import os
import joblib
import pandas as pd
import numpy as np
from datetime import timedelta
from data_fetcher import get_historical_gold_data

MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gold_model.joblib")

_model_artifact = None

def load_model_artifact():
    """Loads the pre-trained model artifact from disk."""
    global _model_artifact
    if _model_artifact is None and os.path.exists(MODEL_PATH):
        try:
            _model_artifact = joblib.load(MODEL_PATH)
        except Exception as e:
            print(f"Error loading model artifact: {e}")
            _model_artifact = None
    return _model_artifact

def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """Calculates Relative Strength Index (RSI)."""
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / (loss.replace(0, np.nan))
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50.0)

def extract_features_df(df: pd.DataFrame) -> pd.DataFrame:
    """Extracts identical feature set used during model training."""
    df = df.copy()
    if 'Close' not in df.columns:
        return df
        
    df['return_1d'] = df['Close'].pct_change(1)
    df['return_5d'] = df['Close'].pct_change(5)
    df['return_10d'] = df['Close'].pct_change(10)
    
    df['sma_7'] = df['Close'].rolling(window=7).mean()
    df['sma_14'] = df['Close'].rolling(window=14).mean()
    df['sma_30'] = df['Close'].rolling(window=30).mean()
    df['sma_50'] = df['Close'].rolling(window=50).mean()
    
    df['ratio_sma_7'] = df['Close'] / df['sma_7']
    df['ratio_sma_14'] = df['Close'] / df['sma_14']
    df['ratio_sma_30'] = df['Close'] / df['sma_30']
    df['ratio_sma_50'] = df['Close'] / df['sma_50']
    
    df['ema_12'] = df['Close'].ewm(span=12, adjust=False).mean()
    df['ema_26'] = df['Close'].ewm(span=26, adjust=False).mean()
    
    df['macd'] = df['ema_12'] - df['ema_26']
    df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']
    
    df['volatility_14'] = df['return_1d'].rolling(window=14).std()
    df['volatility_30'] = df['return_1d'].rolling(window=30).std()
    
    df['rsi_14'] = calculate_rsi(df['Close'], period=14)
    
    df['day_of_week'] = df.index.dayofweek
    df['month'] = df.index.month
    df['quarter'] = df.index.quarter
    
    return df

def train_and_predict(days_to_predict=7):
    """
    Generates multi-day forward forecast using the pre-trained ML model
    trained on 2010-2024 gold prices.
    """
    # Fetch recent historical data (90 days) to compute 50-day SMA & indicators accurately
    df = get_historical_gold_data(days=90)
    
    if df.empty:
        return []
        
    df = df.sort_index()
    last_date = df.index[-1]
    last_price = float(df['Close'].iloc[-1])
    
    artifact = load_model_artifact()
    
    # If model artifact is not available, fallback to short-term linear extrapolation
    if artifact is None:
        from sklearn.linear_model import LinearRegression
        recent_df = df.tail(14).copy()
        recent_df['DayIndex'] = list(range(len(recent_df)))
        X_simple = recent_df[['DayIndex']]
        y_simple = recent_df['Close']
        lr = LinearRegression().fit(X_simple, y_simple)
        slope = float(lr.coef_[0])
        
        predictions = []
        for i in range(days_to_predict):
            target_date = last_date + timedelta(days=i + 1)
            predictions.append({
                "date": target_date.strftime('%Y-%m-%d'),
                "price": last_price + (i + 1) * slope
            })
        return predictions

    model = artifact["model"]
    scaler = artifact["scaler"]
    feature_cols = artifact["feature_columns"]
    
    # Multi-step recursive forecasting
    sim_df = df.copy()
    predictions = []
    
    for i in range(days_to_predict):
        feat_df = extract_features_df(sim_df)
        feat_row = feat_df.iloc[-1:][feature_cols]
        
        # Scale and predict next return
        X_scaled = scaler.transform(feat_row.values)
        pred_return = float(model.predict(X_scaled)[0])
        
        current_price = float(sim_df['Close'].iloc[-1])
        next_price = current_price * (1.0 + pred_return)
        
        next_date = last_date + timedelta(days=i + 1)
        predictions.append({
            "date": next_date.strftime('%Y-%m-%d'),
            "price": float(next_price)
        })
        
        # Append simulated row to rolling series for next iteration step
        new_row = pd.DataFrame([{
            'Open': next_price,
            'High': next_price,
            'Low': next_price,
            'Close': next_price,
            'Volume': float(sim_df['Volume'].mean() if 'Volume' in sim_df else 1000)
        }], index=[next_date])
        
        sim_df = pd.concat([sim_df, new_row])
        
    return predictions
