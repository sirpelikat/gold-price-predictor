import os
import joblib
import pandas as pd
import numpy as np
from datetime import timedelta
import yfinance as yf
from data_fetcher import get_historical_gold_data, get_usd_myr_rate
from prepare_datasets import compute_features

MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "gold_model.joblib")

_model_artifact = None

def load_model_artifact(force_reload: bool = False):
    """Loads or hot-reloads the pre-trained model artifact from disk."""
    global _model_artifact
    if (_model_artifact is None or force_reload) and os.path.exists(MODEL_PATH):
        try:
            _model_artifact = joblib.load(MODEL_PATH)
            print(f"Model artifact loaded successfully: {_model_artifact.get('version', 'v1.0')}")
        except Exception as e:
            print(f"Error loading model artifact: {e}")
            _model_artifact = None
    return _model_artifact

def reload_model():
    """Forces an in-memory hot-reload of the latest promoted model."""
    return load_model_artifact(force_reload=True)

def extract_features_df(df: pd.DataFrame) -> pd.DataFrame:
    """Extracts features using prepare_datasets compute_features."""
    return compute_features(df)

def fetch_recent_multi_asset_data(days=90):
    """
    Fetches aligned recent market history for Gold, USDMYR, Brent Oil, KLCI, DXY, and 10Y Yield.
    """
    ticker_map = {
        'GC=F': 'gold_close',
        'USDMYR=X': 'usdmyr_close',
        'BZ=F': 'oil_close',
        '^KLSE': 'klci_close',
        'DX-Y.NYB': 'dxy_close',
        '^TNX': 'yield_10y_close'
    }
    
    start_dt = (pd.Timestamp.now() - pd.Timedelta(days=days + 60)).strftime('%Y-%m-%d')
    try:
        raw = yf.download(list(ticker_map.keys()), start=start_dt, progress=False)['Close']
        if isinstance(raw.columns, pd.MultiIndex):
            raw.columns = raw.columns.get_level_values(0)
            
        aligned = pd.DataFrame(index=raw.index)
        for ticker, col_name in ticker_map.items():
            if ticker in raw.columns:
                aligned[col_name] = raw[ticker]
            else:
                aligned[col_name] = np.nan
        aligned = aligned.ffill().bfill()
        return aligned
    except Exception as e:
        print(f"Error fetching multi-asset data: {e}")
        # Fallback to single asset
        df_single = get_historical_gold_data(days=days + 60)
        df_aligned = pd.DataFrame(index=df_single.index)
        df_aligned['gold_close'] = df_single['Close']
        df_aligned['usdmyr_close'] = 4.0365
        df_aligned['oil_close'] = 92.0
        df_aligned['klci_close'] = 1736.0
        df_aligned['dxy_close'] = 99.0
        df_aligned['yield_10y_close'] = 4.70
        return df_aligned

def get_historical_with_predictions(days=7):
    """
    Fetches recent historical data and generates dual Malaysian & Global model predictions,
    aligning directly with official 8:00 AM logged snapshots for unified comparison.
    """
    df_raw = fetch_recent_multi_asset_data(days=days + 60)
    if df_raw.empty:
        return []
        
    feat_df = compute_features(df_raw)
    target_slice = feat_df.tail(days).copy()
    results = []
    
    # Load 8:00 AM logged snapshot dictionary
    logged_map = {}
    logs_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "prediction_history.csv")
    if os.path.exists(logs_file):
        try:
            log_df = pd.read_csv(logs_file)
            if not log_df.empty:
                for _, row in log_df.iterrows():
                    t_date = str(row['target_date'])
                    p_myr = row.get('predicted_price_myr_g')
                    p_usd = row.get('predicted_price_usd')
                    if pd.notna(p_usd) and pd.notna(p_myr):
                        logged_map[t_date] = {
                            'pred_usd': float(p_usd),
                            'pred_myr_g': float(p_myr)
                        }
        except Exception as e:
            print(f"Notice reading log map for historical alignment: {e}")

    artifact = load_model_artifact()
    
    if artifact is not None and "engine" in artifact:
        engine = artifact["engine"]
        
        for idx in range(len(target_slice)):
            date_str = target_slice.index[idx].strftime('%Y-%m-%d')
            actual_usd = float(target_slice['gold_usd'].iloc[idx])
            actual_myr_g = float(target_slice['gold_myr_g'].iloc[idx])
            
            # Prefer official 8:00 AM snapshot log if present for perfect alignment
            if date_str in logged_map:
                pred_usd = logged_map[date_str]['pred_usd']
                pred_myr_g = logged_map[date_str]['pred_myr_g']
            else:
                loc_idx = feat_df.index.get_loc(target_slice.index[idx])
                if loc_idx > 0:
                    prev_row = feat_df.iloc[loc_idx - 1:loc_idx]
                    prev_gold_usd = float(feat_df['gold_usd'].iloc[loc_idx - 1])
                    prev_usd_myr = float(feat_df['usd_myr'].iloc[loc_idx - 1])
                    
                    res = engine.predict_components(prev_row, prev_gold_usd, prev_usd_myr)
                    pred_usd = res['predicted_gold_usd']
                    pred_myr_g = res['predicted_myr_g_consensus']
                else:
                    pred_usd = actual_usd
                    pred_myr_g = actual_myr_g
                
            results.append({
                "date": date_str,
                "price": actual_myr_g,
                "price_usd": actual_usd,
                "predicted_price": pred_myr_g,
                "predicted_price_usd": pred_usd
            })
    else:
        for date_val, row in target_slice.iterrows():
            date_str = date_val.strftime('%Y-%m-%d')
            usd_val = float(row['gold_usd'])
            myr_val = float(row['gold_myr_g'])
            if date_str in logged_map:
                p_usd = logged_map[date_str]['pred_usd']
                p_myr = logged_map[date_str]['pred_myr_g']
            else:
                p_usd = usd_val
                p_myr = myr_val
            results.append({
                "date": date_str,
                "price": myr_val,
                "price_usd": usd_val,
                "predicted_price": p_myr,
                "predicted_price_usd": p_usd
            })
            
    return results

def train_and_predict(days_to_predict=7):
    """
    Generates multi-day forward forecast using Malaysian Multi-Task Learning Engine.
    """
    df_raw = fetch_recent_multi_asset_data(days=90)
    if df_raw.empty:
        return []
        
    feat_df = compute_features(df_raw)
    last_date = feat_df.index[-1]
    
    artifact = load_model_artifact()
    troy_oz_to_g = 31.1034768
    
    if artifact is None or "engine" not in artifact:
        # Fallback linear forecast
        rate = get_usd_myr_rate()
        last_usd = float(feat_df['gold_usd'].iloc[-1])
        last_myr_g = (last_usd * rate) / troy_oz_to_g
        predictions = []
        for i in range(days_to_predict):
            target_date = last_date + timedelta(days=i + 1)
            predictions.append({
                "date": target_date.strftime('%Y-%m-%d'),
                "price": round(last_myr_g, 2),
                "price_usd": round(last_usd, 2)
            })
        return predictions

    engine = artifact["engine"]
    sim_df = df_raw.copy()
    predictions = []
    
    for i in range(days_to_predict):
        feat_sim = compute_features(sim_df)
        last_row = feat_sim.iloc[-1:]
        
        cur_gold_usd = float(sim_df['gold_close'].iloc[-1])
        cur_usd_myr = float(sim_df['usdmyr_close'].iloc[-1])
        
        res = engine.predict_components(last_row, cur_gold_usd, cur_usd_myr)
        
        next_gold_usd = res['predicted_gold_usd']
        next_usd_myr = res['predicted_usd_myr']
        next_myr_g = res['predicted_myr_g_consensus']
        
        next_date = last_date + timedelta(days=i + 1)
        predictions.append({
            "date": next_date.strftime('%Y-%m-%d'),
            "price": next_myr_g,
            "price_usd": next_gold_usd,
            "predicted_usd_myr": next_usd_myr
        })
        
        # Append step into simulation
        new_row = pd.DataFrame([{
            'gold_close': next_gold_usd,
            'usdmyr_close': next_usd_myr,
            'oil_close': float(sim_df['oil_close'].iloc[-1]),
            'klci_close': float(sim_df['klci_close'].iloc[-1]),
            'dxy_close': float(sim_df['dxy_close'].iloc[-1]),
            'yield_10y_close': float(sim_df['yield_10y_close'].iloc[-1])
        }], index=[next_date])
        
        sim_df = pd.concat([sim_df, new_row])
        
    return predictions
