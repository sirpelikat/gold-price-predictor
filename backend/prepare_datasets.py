import os
import sys
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Malaysian Major Festival Dates (2010 to 2030) for Seasonality Modeling
FESTIVALS_HARI_RAYA = [
    "2010-09-10", "2011-08-30", "2012-08-19", "2013-08-08", "2014-07-28",
    "2015-07-17", "2016-07-06", "2017-06-25", "2018-06-15", "2019-06-05",
    "2020-05-24", "2021-05-13", "2022-05-02", "2023-04-22", "2024-04-10",
    "2025-03-31", "2026-03-20", "2027-03-10", "2028-02-27", "2029-02-15", "2030-02-05"
]

FESTIVALS_CNY = [
    "2010-02-14", "2011-02-03", "2012-01-23", "2013-02-10", "2014-01-31",
    "2015-02-19", "2016-02-08", "2017-01-28", "2018-02-16", "2019-02-05",
    "2020-01-25", "2021-02-12", "2022-02-01", "2023-01-22", "2024-02-10",
    "2025-01-29", "2026-02-17", "2027-02-06", "2028-01-26", "2029-02-13", "2030-02-02"
]

FESTIVALS_DEEPAVALI = [
    "2010-11-05", "2011-10-26", "2012-11-13", "2013-11-02", "2014-10-22",
    "2015-11-10", "2016-10-29", "2017-10-18", "2018-11-06", "2019-10-27",
    "2020-11-14", "2021-11-04", "2022-10-24", "2023-11-12", "2024-10-31",
    "2025-10-20", "2026-11-08", "2027-10-29", "2028-10-17", "2029-11-05", "2030-10-26"
]

def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """Calculates Relative Strength Index (RSI)."""
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    
    rs = gain / (loss.replace(0, np.nan))
    rsi = 100 - (100 / (1 + rs))
    return rsi.fillna(50.0)

def compute_festival_flags(dt_index: pd.DatetimeIndex) -> pd.DataFrame:
    """Computes 30-day pre-festival indicator flags for Malaysian retail seasonality."""
    raya_dates = pd.to_datetime(FESTIVALS_HARI_RAYA)
    cny_dates = pd.to_datetime(FESTIVALS_CNY)
    deepavali_dates = pd.to_datetime(FESTIVALS_DEEPAVALI)
    
    df_flags = pd.DataFrame(index=dt_index)
    
    # Check if current date is within 30 days before each festival
    def is_within_30d(current_dts, event_dts):
        flags = np.zeros(len(current_dts), dtype=int)
        for evt in event_dts:
            start_window = evt - timedelta(days=30)
            mask = (current_dts >= start_window) & (current_dts <= evt)
            flags = np.maximum(flags, mask.astype(int))
        return flags

    df_flags['is_pre_hari_raya'] = is_within_30d(dt_index, raya_dates)
    df_flags['is_pre_cny'] = is_within_30d(dt_index, cny_dates)
    df_flags['is_pre_deepavali'] = is_within_30d(dt_index, deepavali_dates)
    df_flags['is_festive_season'] = np.maximum.reduce([
        df_flags['is_pre_hari_raya'],
        df_flags['is_pre_cny'],
        df_flags['is_pre_deepavali']
    ])
    return df_flags

def compute_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Computes technical indicators, macroeconomic features, exchange rates,
    and Malaysian seasonality indicators.
    """
    df = df.copy().sort_index()
    
    # Clean numerical columns
    for col in df.columns:
        df[col] = pd.to_numeric(df[col], errors='coerce')
    df = df.ffill().bfill()
    
    # 1. Base Target Synthesis (MYR per gram)
    troy_oz_to_g = 31.1034768
    df['gold_usd'] = df['gold_close'] if 'gold_close' in df.columns else df['Close']
    df['usd_myr'] = df['usdmyr_close'] if 'usdmyr_close' in df.columns else 4.05
    df['gold_myr_g'] = (df['gold_usd'] * df['usd_myr']) / troy_oz_to_g
    
    # 2. Return & Momentum Features
    df['gold_return_1d'] = df['gold_usd'].pct_change(1)
    df['gold_return_5d'] = df['gold_usd'].pct_change(5)
    df['gold_return_10d'] = df['gold_usd'].pct_change(10)
    
    df['myr_return_1d'] = df['usd_myr'].pct_change(1)
    df['myr_return_5d'] = df['usd_myr'].pct_change(5)
    
    df['gold_myr_return_1d'] = df['gold_myr_g'].pct_change(1)
    df['gold_myr_return_5d'] = df['gold_myr_g'].pct_change(5)
    
    # 3. Moving Averages & Trend Ratios
    for w in [7, 14, 30, 50]:
        df[f'gold_sma_{w}'] = df['gold_usd'].rolling(window=w).mean()
        df[f'gold_ratio_sma_{w}'] = df['gold_usd'] / df[f'gold_sma_{w}']
        
        df[f'myr_sma_{w}'] = df['usd_myr'].rolling(window=w).mean()
        df[f'myr_ratio_sma_{w}'] = df['usd_myr'] / df[f'myr_sma_{w}']
        
        df[f'gold_myr_sma_{w}'] = df['gold_myr_g'].rolling(window=w).mean()
        df[f'gold_myr_ratio_{w}'] = df['gold_myr_g'] / df[f'gold_myr_sma_{w}']
        
    # 4. Exponential Moving Averages & MACD
    ema_12 = df['gold_usd'].ewm(span=12, adjust=False).mean()
    ema_26 = df['gold_usd'].ewm(span=26, adjust=False).mean()
    df['gold_macd'] = ema_12 - ema_26
    df['gold_macd_signal'] = df['gold_macd'].ewm(span=9, adjust=False).mean()
    df['gold_macd_hist'] = df['gold_macd'] - df['gold_macd_signal']
    
    # 5. Volatility & RSI
    df['gold_volatility_14'] = df['gold_return_1d'].rolling(window=14).std()
    df['gold_volatility_30'] = df['gold_return_1d'].rolling(window=30).std()
    df['myr_volatility_14'] = df['myr_return_1d'].rolling(window=14).std()
    
    df['gold_rsi_14'] = calculate_rsi(df['gold_usd'], period=14)
    df['myr_rsi_14'] = calculate_rsi(df['usd_myr'], period=14)
    df['gold_myr_rsi_14'] = calculate_rsi(df['gold_myr_g'], period=14)
    
    # 6. Local & Global Macroeconomic Drivers
    if 'oil_close' in df.columns:
        df['oil_return_1d'] = df['oil_close'].pct_change(1)
        df['oil_return_5d'] = df['oil_close'].pct_change(5)
        df['oil_sma_30'] = df['oil_close'].rolling(window=30).mean()
        df['oil_ratio_sma_30'] = df['oil_close'] / df['oil_sma_30']
        df['oil_rsi_14'] = calculate_rsi(df['oil_close'], period=14)
    else:
        df['oil_return_1d'] = 0.0
        df['oil_return_5d'] = 0.0
        df['oil_ratio_sma_30'] = 1.0
        df['oil_rsi_14'] = 50.0

    if 'klci_close' in df.columns:
        df['klci_return_1d'] = df['klci_close'].pct_change(1)
        df['klci_return_5d'] = df['klci_close'].pct_change(5)
        df['klci_sma_30'] = df['klci_close'].rolling(window=30).mean()
        df['klci_ratio_sma_30'] = df['klci_close'] / df['klci_sma_30']
        df['klci_rsi_14'] = calculate_rsi(df['klci_close'], period=14)
    else:
        df['klci_return_1d'] = 0.0
        df['klci_return_5d'] = 0.0
        df['klci_ratio_sma_30'] = 1.0
        df['klci_rsi_14'] = 50.0
        
    if 'dxy_close' in df.columns:
        df['dxy_return_1d'] = df['dxy_close'].pct_change(1)
        df['dxy_return_5d'] = df['dxy_close'].pct_change(5)
    else:
        df['dxy_return_1d'] = 0.0
        df['dxy_return_5d'] = 0.0
        
    if 'yield_10y_close' in df.columns:
        df['yield_change_1d'] = df['yield_10y_close'].diff(1)
        df['yield_change_5d'] = df['yield_10y_close'].diff(5)
    else:
        df['yield_change_1d'] = 0.0
        df['yield_change_5d'] = 0.0

    # 7. Malaysian Festive Seasonality Flags
    fest_df = compute_festival_flags(df.index)
    for col in fest_df.columns:
        df[col] = fest_df[col]
        
    # 8. Calendar Features
    df['day_of_week'] = df.index.dayofweek
    df['month'] = df.index.month
    df['quarter'] = df.index.quarter
    
    # 9. Multi-Task Targets
    df['target_gold_next_close'] = df['gold_usd'].shift(-1)
    df['target_gold_next_return'] = df['gold_return_1d'].shift(-1)
    
    df['target_myr_next_close'] = df['usd_myr'].shift(-1)
    df['target_myr_next_return'] = df['myr_return_1d'].shift(-1)
    
    df['target_gold_myr_next_close'] = df['gold_myr_g'].shift(-1)
    df['target_gold_myr_next_return'] = df['gold_myr_return_1d'].shift(-1)
    
    # Standard alias for backwards compatibility
    df['Close'] = df['gold_usd']
    df['target_next_close'] = df['target_gold_next_close']
    df['target_next_return'] = df['target_gold_next_return']
    
    return df

def fetch_malaysia_macro_dataset(start_date: str = "2010-01-01", end_date: str = "2026-08-25") -> pd.DataFrame:
    """
    Downloads full historical suite of gold and Malaysian macroeconomic drivers.
    """
    print(f"Downloading macro datasets from Yahoo Finance ({start_date} to {end_date})...")
    ticker_map = {
        'GC=F': 'gold_close',
        'USDMYR=X': 'usdmyr_close',
        'BZ=F': 'oil_close',
        '^KLSE': 'klci_close',
        'DX-Y.NYB': 'dxy_close',
        '^TNX': 'yield_10y_close'
    }
    
    df_raw = yf.download(list(ticker_map.keys()), start=start_date, end=end_date, progress=False)['Close']
    if isinstance(df_raw.columns, pd.MultiIndex):
        df_raw.columns = df_raw.columns.get_level_values(0)
        
    df_aligned = pd.DataFrame(index=df_raw.index)
    for ticker, col_name in ticker_map.items():
        if ticker in df_raw.columns:
            df_aligned[col_name] = df_raw[ticker]
            
    df_aligned = df_aligned.ffill().bfill()
    print(f"Raw macro data loaded with shape: {df_aligned.shape}")
    return df_aligned

def generate_datasets():
    data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data")
    os.makedirs(data_dir, exist_ok=True)
    
    df_macro = fetch_malaysia_macro_dataset(start_date="2010-01-01", end_date="2026-08-25")
    feat_df = compute_features(df_macro)
    
    # Drop rows where target is NaN (the last trading day)
    feat_df_clean = feat_df.dropna(subset=['target_gold_next_close', 'target_myr_next_close']).copy()
    
    # Train: 2010 to 2024
    train_df = feat_df_clean[feat_df_clean.index <= "2024-12-31"]
    
    # Test: 2025 Full Year (Out-of-Sample)
    test_df = feat_df_clean[(feat_df_clean.index >= "2025-01-01") & (feat_df_clean.index <= "2025-12-31")]
    
    train_path = os.path.join(data_dir, "gold_train_2010_2024.csv")
    test_path = os.path.join(data_dir, "gold_test_2025.csv")
    
    train_df.to_csv(train_path)
    test_df.to_csv(test_path)
    
    print("=" * 60)
    print(" MALAYSIAN MARKET DATASET PIPELINE COMPLETE ")
    print("=" * 60)
    print(f" Train Dataset (2010-2024) : {len(train_df)} trading days -> {train_path}")
    print(f" Test Dataset  (2025)      : {len(test_df)} trading days  -> {test_path}")
    print(f" Total Features Generated : {len(feat_df.columns)}")
    print("=" * 60)

if __name__ == "__main__":
    generate_datasets()
