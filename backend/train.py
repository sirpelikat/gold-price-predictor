import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import Ridge
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

FEATURE_COLUMNS = [
    'return_1d', 'return_5d', 'return_10d',
    'ratio_sma_7', 'ratio_sma_14', 'ratio_sma_30', 'ratio_sma_50',
    'macd', 'macd_signal', 'macd_hist',
    'volatility_14', 'volatility_30',
    'rsi_14',
    'day_of_week', 'month', 'quarter'
]

def train_model(data_path: str = None, output_model_path: str = None):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if data_path is None:
        data_path = os.path.join(script_dir, "data", "gold_train_2010_2024.csv")
    if output_model_path is None:
        output_model_path = os.path.join(script_dir, "gold_model.joblib")
        
    print(f"Loading training data from: {data_path}")
    df = pd.read_csv(data_path)
    
    # Ensure all required features are present and non-null
    df = df.dropna(subset=FEATURE_COLUMNS + ['target_next_return', 'Close', 'target_next_close']).copy()
    
    X = df[FEATURE_COLUMNS].values
    y_return = df['target_next_return'].values
    y_close = df['target_next_close'].values
    current_close = df['Close'].values
    
    print(f"Training dataset size: {len(X)} records with {len(FEATURE_COLUMNS)} features.")
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Train candidate models on return forecasting
    models = {
        "HistGradientBoosting": HistGradientBoostingRegressor(max_iter=200, max_leaf_nodes=31, learning_rate=0.03, random_state=42),
        "RandomForest": RandomForestRegressor(n_estimators=150, max_depth=8, min_samples_leaf=4, random_state=42, n_jobs=-1),
        "Ridge": Ridge(alpha=10.0, random_state=42)
    }
    
    best_model_name = None
    best_mae = float('inf')
    best_model = None
    
    for name, model in models.items():
        model.fit(X_scaled, y_return)
        pred_returns = model.predict(X_scaled)
        pred_close = current_close * (1 + pred_returns)
        
        mae = mean_absolute_error(y_close, pred_close)
        rmse = np.sqrt(mean_squared_error(y_close, pred_close))
        r2 = r2_score(y_close, pred_close)
        
        print(f"[{name}] Train MAE: ${mae:.2f}, RMSE: ${rmse:.2f}, R2: {r2:.4f}")
        
        if mae < best_mae:
            best_mae = mae
            best_model_name = name
            best_model = model
            
    print(f"\nSelected best model: {best_model_name} (MAE: ${best_mae:.2f})")
    
    # Bundle model artifact with scaler and metadata
    artifact = {
        "model": best_model,
        "model_name": best_model_name,
        "scaler": scaler,
        "feature_columns": FEATURE_COLUMNS,
        "train_period": "2010-01-01 to 2024-12-31",
        "records_count": len(df),
        "train_mae": float(best_mae)
    }
    
    joblib.dump(artifact, output_model_path)
    print(f"[SUCCESS] Model artifact saved to: {output_model_path}")
    return artifact

if __name__ == "__main__":
    train_model()
