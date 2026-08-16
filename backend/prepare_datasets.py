import os
import yfinance as yf
import pandas as pd
import numpy as np

def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """Calculates Relative Strength Index (RSI)."""
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    
    rs = gain / (loss.replace(0, np.nan))
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50.0)

def compute_features(df: pd.DataFrame) -> pd.DataFrame:
    """Computes technical indicators, lags, and rolling features on gold data."""
    df = df.copy()
    
    # Sort chronologically
    df = df.sort_index()
    
    # Clean Close and other standard columns
    for col in ['Open', 'High', 'Low', 'Close', 'Volume']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce')
            
    df = df.ffill().bfill()
    
    # Return features
    df['return_1d'] = df['Close'].pct_change(1)
    df['return_5d'] = df['Close'].pct_change(5)
    df['return_10d'] = df['Close'].pct_change(10)
    
    # Simple Moving Averages
    df['sma_7'] = df['Close'].rolling(window=7).mean()
    df['sma_14'] = df['Close'].rolling(window=14).mean()
    df['sma_30'] = df['Close'].rolling(window=30).mean()
    df['sma_50'] = df['Close'].rolling(window=50).mean()
    
    # Price to SMA ratios (Mean-reversion / trend distance indicators)
    df['ratio_sma_7'] = df['Close'] / df['sma_7']
    df['ratio_sma_14'] = df['Close'] / df['sma_14']
    df['ratio_sma_30'] = df['Close'] / df['sma_30']
    df['ratio_sma_50'] = df['Close'] / df['sma_50']
    
    # Exponential Moving Averages
    df['ema_12'] = df['Close'].ewm(span=12, adjust=False).mean()
    df['ema_26'] = df['Close'].ewm(span=26, adjust=False).mean()
    
    # MACD
    df['macd'] = df['ema_12'] - df['ema_26']
    df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']
    
    # Volatility (Rolling standard deviation of returns)
    df['volatility_14'] = df['return_1d'].rolling(window=14).std()
    df['volatility_30'] = df['return_1d'].rolling(window=30).std()
    
    # RSI
    df['rsi_14'] = calculate_rsi(df['Close'], period=14)
    
    # Lagged close prices
    df['lag_1'] = df['Close'].shift(1)
    df['lag_2'] = df['Close'].shift(2)
    df['lag_3'] = df['Close'].shift(3)
    df['lag_7'] = df['Close'].shift(7)
    df['lag_14'] = df['Close'].shift(14)
    
    # Calendar features
    df['day_of_week'] = df.index.dayofweek
    df['month'] = df.index.month
    df['quarter'] = df.index.quarter
    
    # Target: Next Day's Close price and Next Day's Return %
    df['target_next_close'] = df['Close'].shift(-1)
    df['target_next_return'] = df['return_1d'].shift(-1)
    
    return df

def download_and_prepare_datasets(data_dir: str = "data"):
    """
    Downloads historical data from 2009-10-01 to 2025-12-31 to build complete indicators,
    then slices and saves:
      1. gold_train_2010_2024.csv (2010-01-01 to 2024-12-31)
      2. gold_test_2025.csv (2025-01-01 to 2025-12-31)
    """
    os.makedirs(data_dir, exist_ok=True)
    
    print("Fetching gold futures (GC=F) data from Yahoo Finance...")
    # Start earlier in 2009 to warm up 50-day rolling windows
    raw_df = yf.download("GC=F", start="2009-10-01", end="2026-01-05", progress=False)
    
    if raw_df.empty:
        raise RuntimeError("Failed to fetch gold data from Yahoo Finance.")
        
    # Handle multi-level columns if returned by yfinance
    if isinstance(raw_df.columns, pd.MultiIndex):
        raw_df.columns = raw_df.columns.get_level_values(0)
        
    raw_df.index = pd.to_datetime(raw_df.index)
    raw_df.index.name = "Date"
    
    print(f"Downloaded {len(raw_df)} trading days total. Computing features...")
    df_features = compute_features(raw_df)
    
    # Reset index so 'Date' is an explicit column
    df_features = df_features.reset_index()
    df_features['Date'] = pd.to_datetime(df_features['Date']).dt.strftime('%Y-%m-%d')
    
    # Slice 2010-2024 Training Set
    train_df = df_features[
        (df_features['Date'] >= "2010-01-01") & 
        (df_features['Date'] <= "2024-12-31")
    ].copy()
    
    # Slice 2025 Testing Set
    test_df = df_features[
        (df_features['Date'] >= "2025-01-01") & 
        (df_features['Date'] <= "2025-12-31")
    ].copy()
    
    # Drop rows where target_next_close is NaN in training set
    train_df_clean = train_df.dropna(subset=['target_next_close', 'sma_50', 'volatility_30']).copy()
    test_df_clean = test_df.dropna(subset=['sma_50', 'volatility_30']).copy()
    
    train_path = os.path.join(data_dir, "gold_train_2010_2024.csv")
    test_path = os.path.join(data_dir, "gold_test_2025.csv")
    
    train_df_clean.to_csv(train_path, index=False)
    test_df_clean.to_csv(test_path, index=False)
    
    print(f"[SUCCESS] Training dataset (2010-2024) saved to: {train_path} ({len(train_df_clean)} rows, {len(train_df_clean.columns)} columns)")
    print(f"   Date range: {train_df_clean['Date'].min()} to {train_df_clean['Date'].max()}")
    print(f"[SUCCESS] Testing dataset (2025) saved to: {test_path} ({len(test_df_clean)} rows, {len(test_df_clean.columns)} columns)")
    print(f"   Date range: {test_df_clean['Date'].min()} to {test_df_clean['Date'].max()}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    target_data_dir = os.path.join(script_dir, "data")
    download_and_prepare_datasets(target_data_dir)
