import os
import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score

def evaluate_model_2025(test_data_path: str = None, model_path: str = None, output_csv_path: str = None):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if test_data_path is None:
        test_data_path = os.path.join(script_dir, "data", "gold_test_2025.csv")
    if model_path is None:
        model_path = os.path.join(script_dir, "gold_model.joblib")
    if output_csv_path is None:
        output_csv_path = os.path.join(script_dir, "data", "eval_results_2025.csv")
        
    print(f"Loading 2025 test dataset from: {test_data_path}")
    test_df = pd.read_csv(test_data_path)
    
    print(f"Loading trained model artifact from: {model_path}")
    artifact = joblib.load(model_path)
    model = artifact["model"]
    scaler = artifact["scaler"]
    feature_columns = artifact["feature_columns"]
    
    # Filter rows with target_next_close available
    eval_df = test_df.dropna(subset=feature_columns + ['target_next_close', 'Close']).copy()
    
    X = eval_df[feature_columns].values
    X_scaled = scaler.transform(X)
    current_close = eval_df['Close'].values
    actual_next_close = eval_df['target_next_close'].values
    
    # Predict next day return and calculate predicted price
    pred_returns = model.predict(X_scaled)
    predicted_next_close = current_close * (1 + pred_returns)
    
    # Compute Metrics
    mae_usd = mean_absolute_error(actual_next_close, predicted_next_close)
    rmse_usd = np.sqrt(mean_squared_error(actual_next_close, predicted_next_close))
    mape = np.mean(np.abs((actual_next_close - predicted_next_close) / actual_next_close)) * 100
    r2 = r2_score(actual_next_close, predicted_next_close)
    
    # Directional Accuracy (Did model correctly predict up/down day?)
    actual_direction = np.sign(actual_next_close - current_close)
    pred_direction = np.sign(predicted_next_close - current_close)
    directional_accuracy = np.mean(actual_direction == pred_direction) * 100
    
    # Approximate USD to MYR (e.g. 4.45) for MYR/g conversion
    usd_to_myr = 4.45
    troy_oz_to_g = 31.1034768
    mae_myr_g = (mae_usd * usd_to_myr) / troy_oz_to_g
    
    print("\n" + "=" * 55)
    print(" [REPORT] 2025 OUT-OF-SAMPLE MODEL EVALUATION RESULTS ")
    print("=" * 55)
    print(f" Model Name            : {artifact['model_name']}")
    print(f" Evaluation Period     : 2025-01-01 to 2025-12-31 ({len(eval_df)} trading days)")
    print(f" Mean Absolute Error   : ${mae_usd:.2f}/oz (RM {mae_myr_g:.2f}/g)")
    print(f" Root Mean Sq Error    : ${rmse_usd:.2f}/oz")
    print(f" MAPE (Mean Error %)   : {mape:.2f}%")
    print(f" Directional Accuracy  : {directional_accuracy:.2f}%")
    print(f" R2 Score              : {r2:.4f}")
    print("=" * 55)
    
    # Save detailed evaluation comparison
    eval_df['predicted_next_close'] = predicted_next_close
    eval_df['absolute_error'] = np.abs(actual_next_close - predicted_next_close)
    eval_df['percentage_error'] = (eval_df['absolute_error'] / actual_next_close) * 100
    
    results_export = eval_df[['Date', 'Close', 'target_next_close', 'predicted_next_close', 'absolute_error', 'percentage_error']].copy()
    results_export.rename(columns={'target_next_close': 'actual_next_close'}, inplace=True)
    results_export.to_csv(output_csv_path, index=False)
    print(f"\n[SUCCESS] Detailed evaluation results saved to: {output_csv_path}")
    
    return {
        "model_name": artifact["model_name"],
        "mae_usd": round(mae_usd, 2),
        "mae_myr_g": round(mae_myr_g, 2),
        "rmse_usd": round(rmse_usd, 2),
        "mape_percent": round(mape, 2),
        "directional_accuracy_percent": round(directional_accuracy, 2),
        "r2_score": round(r2, 4),
        "test_records": len(eval_df)
    }

if __name__ == "__main__":
    evaluate_model_2025()
