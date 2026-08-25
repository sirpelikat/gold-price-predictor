import os
import joblib
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from train import ALL_FEATURE_COLUMNS

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
    
    clean_cols = ALL_FEATURE_COLUMNS + [
        'target_gold_next_close', 'target_gold_myr_next_close',
        'gold_usd', 'usd_myr', 'gold_myr_g'
    ]
    eval_df = test_df.dropna(subset=clean_cols).copy()
    
    if "engine" in artifact:
        engine = artifact["engine"]
        batch_res = engine.predict_batch(eval_df)
        pred_usd = batch_res["predicted_gold_usd"]
        pred_myr_g = batch_res["predicted_myr_g_consensus"]
        pred_fx = batch_res["predicted_usd_myr"]
    else:
        model = artifact["model"]
        scaler = artifact["scaler"]
        X = eval_df[artifact["feature_columns"]].values
        pred_returns = model.predict(scaler.transform(X))
        pred_usd = eval_df['gold_usd'].values * (1 + pred_returns)
        pred_myr_g = (pred_usd * eval_df['usd_myr'].values) / 31.1034768
        pred_fx = eval_df['usd_myr'].values
        
    actual_usd = eval_df['target_gold_next_close'].values
    actual_myr_g = eval_df['target_gold_myr_next_close'].values
    cur_usd = eval_df['gold_usd'].values
    cur_myr_g = eval_df['gold_myr_g'].values
    
    # Metrics for USD
    mae_usd = mean_absolute_error(actual_usd, pred_usd)
    rmse_usd = np.sqrt(mean_squared_error(actual_usd, pred_usd))
    mape_usd = np.mean(np.abs((actual_usd - pred_usd) / actual_usd)) * 100
    r2_usd = r2_score(actual_usd, pred_usd)
    
    # Metrics for MYR / g
    mae_myr_g = mean_absolute_error(actual_myr_g, pred_myr_g)
    rmse_myr_g = np.sqrt(mean_squared_error(actual_myr_g, pred_myr_g))
    mape_myr_g = np.mean(np.abs((actual_myr_g - pred_myr_g) / actual_myr_g)) * 100
    r2_myr_g = r2_score(actual_myr_g, pred_myr_g)
    
    # Directional Accuracy (MYR/g)
    actual_dir_myr = np.sign(actual_myr_g - cur_myr_g)
    pred_dir_myr = np.sign(pred_myr_g - cur_myr_g)
    dir_acc_myr = np.mean(actual_dir_myr == pred_dir_myr) * 100
    
    print("\n" + "=" * 60)
    print(" [REPORT] 2025 MALAYSIAN MULTI-TASK EVALUATION RESULTS ")
    print("=" * 60)
    print(f" Model Engine          : {artifact.get('model_name', 'MalaysianMultiTaskMTL')}")
    print(f" Evaluation Period     : 2025-01-01 to 2025-12-31 ({len(eval_df)} trading days)")
    print(f" Malaysian Gold (MYR/g): MAE RM {mae_myr_g:.2f}/g | MAPE {mape_myr_g:.2f}% | R2 {r2_myr_g:.4f}")
    print(f" Global Gold (USD/oz)  : MAE ${mae_usd:.2f}/oz | MAPE {mape_usd:.2f}% | R2 {r2_usd:.4f}")
    print(f" Directional Accuracy  : {dir_acc_myr:.2f}% (MYR/g market direction)")
    print("=" * 60)
    
    eval_df['predicted_gold_usd'] = pred_usd
    eval_df['actual_gold_usd'] = actual_usd
    eval_df['predicted_gold_myr_g'] = pred_myr_g
    eval_df['actual_gold_myr_g'] = actual_myr_g
    eval_df['predicted_usd_myr'] = pred_fx
    eval_df['error_usd'] = np.abs(actual_usd - pred_usd)
    eval_df['error_myr_g'] = np.abs(actual_myr_g - pred_myr_g)
    eval_df['percentage_error'] = (eval_df['error_myr_g'] / actual_myr_g) * 100
    
    results_export = eval_df[[
        'Date', 'gold_usd', 'actual_gold_usd', 'predicted_gold_usd',
        'usd_myr', 'predicted_usd_myr',
        'gold_myr_g', 'actual_gold_myr_g', 'predicted_gold_myr_g',
        'error_myr_g', 'percentage_error'
    ]].copy()
    results_export.to_csv(output_csv_path, index=False)
    print(f"\n[SUCCESS] Detailed evaluation results saved to: {output_csv_path}")
    
    return {
        "model_name": artifact.get("model_name", "MalaysianMultiTaskMTL"),
        "2025_test_mae_usd": round(mae_usd, 2),
        "2025_test_mae_myr_g": round(mae_myr_g, 2),
        "2025_test_rmse_usd": round(rmse_usd, 2),
        "2025_test_mape_percent": round(mape_myr_g, 2),
        "2025_test_directional_accuracy": round(dir_acc_myr, 2),
        "2025_test_r2_myr_g": round(r2_myr_g, 4),
        "test_records": len(eval_df)
    }

if __name__ == "__main__":
    evaluate_model_2025()
