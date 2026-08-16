import os
import joblib
import numpy as np
import pandas as pd
import yfinance as yf
from prepare_datasets import compute_features

def predict_jan_to_july_2026(model_path: str = None, output_csv_path: str = None):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if model_path is None:
        model_path = os.path.join(script_dir, "gold_model.joblib")
    if output_csv_path is None:
        output_csv_path = os.path.join(script_dir, "data", "predictions_2026_jan_july.csv")
        
    print(f"Loading trained model artifact from: {model_path}")
    artifact = joblib.load(model_path)
    model = artifact["model"]
    scaler = artifact["scaler"]
    feature_columns = artifact["feature_columns"]
    
    print("Fetching gold data from late 2025 through July 31, 2026...")
    # Fetch from late 2025 to warm up 50-day rolling indicators
    raw_df = yf.download("GC=F", start="2025-10-01", end="2026-08-01", progress=False)
    
    if raw_df.empty:
        raise RuntimeError("Failed to fetch 2026 gold data from Yahoo Finance.")
        
    if isinstance(raw_df.columns, pd.MultiIndex):
        raw_df.columns = raw_df.columns.get_level_values(0)
        
    raw_df.index = pd.to_datetime(raw_df.index)
    raw_df.index.name = "Date"
    
    # Compute technical features
    df_features = compute_features(raw_df)
    df_features = df_features.reset_index()
    df_features['Date'] = pd.to_datetime(df_features['Date']).dt.strftime('%Y-%m-%d')
    
    # Filter for January 1, 2026 to July 31, 2026
    df_2026 = df_features[
        (df_features['Date'] >= "2026-01-01") & 
        (df_features['Date'] <= "2026-07-31")
    ].copy()
    
    if df_2026.empty:
        raise RuntimeError("No trading data found in range 2026-01-01 to 2026-07-31.")
        
    # Extract features and scale
    X = df_2026[feature_columns].values
    X_scaled = scaler.transform(X)
    current_close = df_2026['Close'].values
    actual_next_close = df_2026['target_next_close'].values
    
    # Predict next day return and predicted price
    pred_returns = model.predict(X_scaled)
    predicted_next_close = current_close * (1 + pred_returns)
    
    # Add predicted values to dataframe
    df_2026['predicted_next_close'] = predicted_next_close
    df_2026['actual_next_close'] = actual_next_close
    
    # Conversion rate USD -> MYR
    usd_to_myr = 4.45
    troy_oz_to_g = 31.1034768
    
    df_2026['predicted_myr_per_g'] = (df_2026['predicted_next_close'] * usd_to_myr) / troy_oz_to_g
    df_2026['actual_myr_per_g'] = (df_2026['actual_next_close'] * usd_to_myr) / troy_oz_to_g
    
    # Filter valid comparison rows
    valid_mask = ~df_2026['actual_next_close'].isna()
    eval_df = df_2026[valid_mask].copy()
    
    eval_df['absolute_error_usd'] = np.abs(eval_df['actual_next_close'] - eval_df['predicted_next_close'])
    eval_df['percentage_error'] = (eval_df['absolute_error_usd'] / eval_df['actual_next_close']) * 100
    eval_df['absolute_error_myr_g'] = (eval_df['absolute_error_usd'] * usd_to_myr) / troy_oz_to_g
    
    # Overall metrics
    overall_mae_usd = eval_df['absolute_error_usd'].mean()
    overall_mae_myr_g = eval_df['absolute_error_myr_g'].mean()
    overall_mape = eval_df['percentage_error'].mean()
    
    # Export clean predictions CSV
    export_cols = [
        'Date', 'Close', 'actual_next_close', 'predicted_next_close',
        'absolute_error_usd', 'percentage_error', 'predicted_myr_per_g', 'actual_myr_per_g'
    ]
    eval_df[export_cols].to_csv(output_csv_path, index=False)
    
    print("\n" + "=" * 65)
    print(" [REPORT] 2026 (JANUARY - JULY) GOLD PRICE PREDICTION RESULTS ")
    print("=" * 65)
    print(f" Model Used            : {artifact['model_name']}")
    print(f" Period Evaluated      : 2026-01-01 to 2026-07-31 ({len(eval_df)} trading days)")
    print(f" Mean Absolute Error   : ${overall_mae_usd:.2f}/oz (RM {overall_mae_myr_g:.2f}/g)")
    print(f" MAPE (Mean Error %)   : {overall_mape:.2f}%")
    print(f" Overall Accuracy      : {100 - overall_mape:.2f}%")
    print("=" * 65)
    
    # Monthly breakdown table
    eval_df['Month'] = pd.to_datetime(eval_df['Date']).dt.strftime('%Y-%m (%B)')
    monthly_summary = eval_df.groupby('Month').agg(
        Trading_Days=('Date', 'count'),
        Avg_Actual_Price_USD=('actual_next_close', 'mean'),
        Avg_Predicted_Price_USD=('predicted_next_close', 'mean'),
        MAE_USD=('absolute_error_usd', 'mean'),
        MAPE_Percent=('percentage_error', 'mean')
    ).reset_index()
    
    print("\n--- Monthly Performance Breakdown (Jan - Jul 2026) ---")
    for _, row in monthly_summary.iterrows():
        print(f" * {row['Month']:<22} | Days: {row['Trading_Days']:2d} | Avg Actual: ${row['Avg_Actual_Price_USD']:.2f} | Avg Pred: ${row['Avg_Predicted_Price_USD']:.2f} | MAE: ${row['MAE_USD']:.2f} | Error: {row['MAPE_Percent']:.2f}%")
        
    print("=" * 65)
    print(f"[SUCCESS] Full 2026 daily predictions exported to: {output_csv_path}")
    return monthly_summary

if __name__ == "__main__":
    predict_jan_to_july_2026()
