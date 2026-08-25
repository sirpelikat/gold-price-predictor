import os
import joblib
import pandas as pd
from sklearn.metrics import mean_absolute_error
from engine import MalaysianMultiTaskGoldEngine, ALL_FEATURE_COLUMNS

def train_model(data_path: str = None, output_model_path: str = None):
    script_dir = os.path.dirname(os.path.abspath(__file__))
    if data_path is None:
        data_path = os.path.join(script_dir, "data", "gold_train_2010_2024.csv")
    if output_model_path is None:
        output_model_path = os.path.join(script_dir, "gold_model.joblib")
        
    print(f"Loading Malaysian Market Training Data: {data_path}")
    df = pd.read_csv(data_path)
    
    clean_cols = ALL_FEATURE_COLUMNS + [
        'target_gold_next_return', 'target_gold_next_close',
        'target_myr_next_return', 'target_myr_next_close',
        'target_gold_myr_next_return', 'target_gold_myr_next_close',
        'gold_usd', 'usd_myr', 'gold_myr_g'
    ]
    df = df.dropna(subset=clean_cols).copy()
    
    print(f"Training MTL Engine on {len(df)} historical trading days...")
    mtl_engine = MalaysianMultiTaskGoldEngine()
    mtl_engine.fit(df)
    
    # Vectorized in-sample evaluation
    batch_res = mtl_engine.predict_batch(df)
    preds_usd = batch_res['predicted_gold_usd']
    preds_myr_g = batch_res['predicted_myr_g_consensus']
        
    act_usd = df['target_gold_next_close'].values
    act_myr_g = df['target_gold_myr_next_close'].values
    
    mae_usd = mean_absolute_error(act_usd, preds_usd)
    mae_myr_g = mean_absolute_error(act_myr_g, preds_myr_g)
    
    print("=" * 60)
    print(" MALAYSIAN MULTI-TASK LEARNING ENGINE TRAINED ")
    print("=" * 60)
    print(f" Model A (Global Gold USD MAE) : ${mae_usd:.2f} / oz")
    print(f" Combiner (Malaysian Gold MAE)  : RM {mae_myr_g:.2f} / g")
    print("=" * 60)
    
    artifact = {
        "engine": mtl_engine,
        "model": mtl_engine.model_gold,
        "scaler": mtl_engine.scaler_gold,
        "feature_columns": ALL_FEATURE_COLUMNS,
        "model_name": "MalaysianMultiTaskMTL",
        "train_period": "2010-01-01 to 2024-12-31",
        "records_count": len(df),
        "train_mae_usd": float(mae_usd),
        "train_mae_myr_g": float(mae_myr_g)
    }
    
    joblib.dump(artifact, output_model_path)
    print(f"[SUCCESS] Model artifact saved to: {output_model_path}")
    return artifact

if __name__ == "__main__":
    train_model()
