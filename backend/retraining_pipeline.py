import os
import shutil
import json
from datetime import datetime, timezone
import pandas as pd
import numpy as np
import joblib
from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, mean_squared_error

from prepare_datasets import fetch_malaysia_macro_dataset, compute_features
from engine import MalaysianMultiTaskGoldEngine, ALL_FEATURE_COLUMNS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
MODELS_DIR = os.path.join(BASE_DIR, "models")
ARCHIVE_DIR = os.path.join(MODELS_DIR, "archive")
REGISTRY_FILE = os.path.join(MODELS_DIR, "model_registry.json")
PRODUCTION_MODEL_PATH = os.path.join(BASE_DIR, "gold_model.joblib")
MASTER_TIMELINE_PATH = os.path.join(DATA_DIR, "gold_master_timeline.csv")

def ensure_directories():
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(MODELS_DIR, exist_ok=True)
    os.makedirs(ARCHIVE_DIR, exist_ok=True)

def load_model_registry() -> dict:
    ensure_directories()
    if os.path.exists(REGISTRY_FILE):
        try:
            with open(REGISTRY_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "production_version": "v1.0.0",
        "last_retrained_at": "2026-08-25 15:00:00 UTC",
        "history": []
    }

def save_model_registry(registry_data: dict):
    ensure_directories()
    with open(REGISTRY_FILE, "w") as f:
        json.dump(registry_data, f, indent=2)

def run_data_ingestion_and_feature_sync() -> pd.DataFrame:
    """
    Step 1: Data Ingestion & Feature Sync
    Pulls fresh daily closes from Yahoo Finance and BNM, computes all technical and macro features.
    """
    print("[1/4] Ingesting latest multi-asset market data...")
    today_str = datetime.now().strftime('%Y-%m-%d')
    raw_macro = fetch_malaysia_macro_dataset(start_date="2010-01-01", end_date=today_str)
    feat_df = compute_features(raw_macro)
    
    clean_cols = ALL_FEATURE_COLUMNS + [
        'target_gold_next_return', 'target_gold_next_close',
        'target_myr_next_return', 'target_myr_next_close',
        'target_gold_myr_next_return', 'target_gold_myr_next_close',
        'gold_usd', 'usd_myr', 'gold_myr_g'
    ]
    clean_df = feat_df.dropna(subset=clean_cols).copy()
    clean_df.to_csv(MASTER_TIMELINE_PATH)
    print(f"Master timeline updated: {len(clean_df)} trading days saved to {MASTER_TIMELINE_PATH}")
    return clean_df

def evaluate_walk_forward_cv(df: pd.DataFrame, n_splits: int = 5) -> dict:
    """
    Step 2: Walk-Forward Cross-Validation
    Slices dataset chronologically into 5 expanding-window folds.
    """
    print(f"[2/4] Executing Walk-Forward Cross-Validation ({n_splits} chronological folds)...")
    tscv = TimeSeriesSplit(n_splits=n_splits)
    
    fold_metrics = []
    
    for fold_idx, (train_idx, val_idx) in enumerate(tscv.split(df)):
        train_fold = df.iloc[train_idx]
        val_fold = df.iloc[val_idx]
        
        # Train candidate engine on fold
        engine = MalaysianMultiTaskGoldEngine()
        engine.fit(train_fold)
        
        # Predict on out-of-fold validation set
        val_res = engine.predict_batch(val_fold)
        pred_usd = val_res['predicted_gold_usd']
        pred_myr_g = val_res['predicted_myr_g_consensus']
        
        act_usd = val_fold['target_gold_next_close'].values
        act_myr_g = val_fold['target_gold_myr_next_close'].values
        
        mae_usd = mean_absolute_error(act_usd, pred_usd)
        mae_myr_g = mean_absolute_error(act_myr_g, pred_myr_g)
        mape_myr_g = np.mean(np.abs((act_myr_g - pred_myr_g) / act_myr_g)) * 100
        
        start_date = str(val_fold.index[0])[:10]
        end_date = str(val_fold.index[-1])[:10]
        
        fold_metrics.append({
            "fold": fold_idx + 1,
            "val_period": f"{start_date} to {end_date}",
            "val_samples": len(val_fold),
            "mae_usd": round(float(mae_usd), 2),
            "mae_myr_g": round(float(mae_myr_g), 2),
            "mape_percent": round(float(mape_myr_g), 2)
        })
        print(f"   Fold {fold_idx + 1} ({start_date} -> {end_date}): MAE RM {mae_myr_g:.2f}/g | MAPE {mape_myr_g:.2f}% | USD MAE ${mae_usd:.2f}")

    avg_mae_usd = float(np.mean([f['mae_usd'] for f in fold_metrics]))
    avg_mae_myr_g = float(np.mean([f['mae_myr_g'] for f in fold_metrics]))
    avg_mape = float(np.mean([f['mape_percent'] for f in fold_metrics]))
    
    print(f"Aggregated Walk-Forward Validation: MAE RM {avg_mae_myr_g:.2f}/g | MAPE {avg_mape:.2f}%")
    return {
        "avg_mae_usd": round(avg_mae_usd, 2),
        "avg_mae_myr_g": round(avg_mae_myr_g, 2),
        "avg_mape_percent": round(avg_mape, 2),
        "folds": fold_metrics
    }

def evaluate_promotion_gate(candidate_cv: dict, current_production_mae_myr: float = 6.00) -> tuple:
    """
    Step 3: The Promotion Gate
    Evaluates candidate model against safety thresholds.
    """
    print("[3/4] Evaluating candidate model in the Promotion Gate...")
    cand_mape = candidate_cv['avg_mape_percent']
    cand_mae_myr = candidate_cv['avg_mae_myr_g']
    
    # Gate rules:
    # 1. MAPE must be <= 1.50% (98.5% accuracy)
    # 2. Candidate MAE must not exceed production benchmark by more than 10% tolerance
    max_allowed_mae = current_production_mae_myr * 1.10
    
    is_mape_valid = cand_mape <= 1.50
    is_mae_valid = cand_mae_myr <= max_allowed_mae
    
    passed = is_mape_valid and is_mae_valid
    reason = "Candidate passed all safety checks." if passed else (
        f"Gate rejected: Candidate MAE (RM {cand_mae_myr:.2f}/g) or MAPE ({cand_mape:.2f}%) exceeds safety tolerance."
    )
    
    print(f"   Gate Result: {'PROMOTED' if passed else 'ABORTED'}")
    print(f"   Reason: {reason}")
    return passed, reason

def run_automated_retraining_pipeline(force: bool = False) -> dict:
    """
    Full Orchestrated Retraining Pipeline Execution.
    """
    ensure_directories()
    registry = load_model_registry()
    timestamp_str = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
    now_readable = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
    
    # 1. Ingestion
    df = run_data_ingestion_and_feature_sync()
    
    # 2. Walk-Forward CV
    cv_results = evaluate_walk_forward_cv(df, n_splits=5)
    
    # 3. Promotion Gate
    passed, reason = evaluate_promotion_gate(cv_results, current_production_mae_myr=5.50)
    
    if not passed and not force:
        execution_record = {
            "version": f"candidate_{timestamp_str}",
            "timestamp": now_readable,
            "status": "REJECTED_BY_GATE",
            "reason": reason,
            "cv_metrics": cv_results
        }
        registry["history"].insert(0, execution_record)
        save_model_registry(registry)
        return {
            "status": "gate_rejected",
            "promoted": False,
            "reason": reason,
            "metrics": cv_results
        }

    # 4. Model Archival, Hot-Swap & Versioning
    print("[4/4] Promoting candidate model and serializing versioned artifact...")
    
    # Train champion on full expanding dataset
    champion_engine = MalaysianMultiTaskGoldEngine()
    champion_engine.fit(df)
    
    new_version = f"v{datetime.now().strftime('%Y.%m.%d')}_{timestamp_str[-4:]}"
    archived_filename = f"gold_model_{new_version}.joblib"
    archived_path = os.path.join(ARCHIVE_DIR, archived_filename)
    
    # Archive previous production model if it exists
    if os.path.exists(PRODUCTION_MODEL_PATH):
        prev_archive_name = f"gold_model_prev_{timestamp_str}.joblib"
        shutil.copyfile(PRODUCTION_MODEL_PATH, os.path.join(ARCHIVE_DIR, prev_archive_name))
        
    artifact = {
        "engine": champion_engine,
        "model": champion_engine.model_gold,
        "scaler": champion_engine.scaler_gold,
        "feature_columns": ALL_FEATURE_COLUMNS,
        "model_name": "MalaysianMultiTaskMTL",
        "version": new_version,
        "trained_at": now_readable,
        "records_count": len(df),
        "cv_mae_myr_g": cv_results['avg_mae_myr_g'],
        "cv_mape_percent": cv_results['avg_mape_percent']
    }
    
    # Save to archive and swap production
    joblib.dump(artifact, archived_path)
    joblib.dump(artifact, PRODUCTION_MODEL_PATH)
    
    # Trigger hot-swap in memory
    try:
        from model import reload_model
        reload_model()
    except Exception as e:
        print(f"In-memory hot-swap notification: {e}")
        
    execution_record = {
        "version": new_version,
        "timestamp": now_readable,
        "status": "PROMOTED_TO_PRODUCTION",
        "archived_path": archived_path,
        "cv_metrics": cv_results,
        "records_count": len(df)
    }
    
    registry["production_version"] = new_version
    registry["last_retrained_at"] = now_readable
    registry["history"].insert(0, execution_record)
    save_model_registry(registry)
    
    print("=" * 60)
    print(" AUTOMATED RETRAINING PIPELINE COMPLETED SUCCESSFULLY ")
    print(f" Promoted Version   : {new_version}")
    print(f" Production Model   : {PRODUCTION_MODEL_PATH}")
    print(f" Walk-Forward MAE   : RM {cv_results['avg_mae_myr_g']:.2f} / g")
    print(f" Walk-Forward MAPE  : {cv_results['avg_mape_percent']:.2f}% (Accuracy: {100 - cv_results['avg_mape_percent']:.2f}%)")
    print("=" * 60)
    
    return {
        "status": "success",
        "promoted": True,
        "version": new_version,
        "metrics": cv_results
    }

if __name__ == "__main__":
    print("Testing Automated Retraining Pipeline...")
    res = run_automated_retraining_pipeline(force=True)
    print("Result:", res)
