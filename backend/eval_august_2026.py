import os
import yfinance as yf
import pandas as pd
import numpy as np
import joblib
from model import extract_features_df, load_model_artifact

def eval_august():
    raw_df = yf.download('GC=F', start='2026-05-01', end='2026-08-31', progress=False)
    if isinstance(raw_df.columns, pd.MultiIndex):
        raw_df.columns = raw_df.columns.get_level_values(0)
    raw_df.index = pd.to_datetime(raw_df.index)

    artifact = load_model_artifact()
    model = artifact['model']
    scaler = artifact['scaler']
    feature_cols = artifact['feature_columns']

    feat_df = extract_features_df(raw_df)
    aug_df = feat_df[(feat_df.index >= '2026-08-01') & (feat_df.index <= '2026-08-31')].copy()

    usd_to_myr = 4.45
    oz_to_g = 31.1034768

    eval_rows = []
    for idx in range(len(aug_df) - 1):
        target_dt_str = aug_df.index[idx+1].strftime('%Y-%m-%d (%a)')
        
        f_row = aug_df.iloc[idx:idx+1][feature_cols]
        if not f_row.isna().any().any():
            x_sc = scaler.transform(f_row.values)
            pred_ret = float(model.predict(x_sc)[0])
            
            cur_usd = float(aug_df['Close'].iloc[idx])
            act_next_usd = float(aug_df['Close'].iloc[idx+1])
            pred_next_usd = cur_usd * (1.0 + pred_ret)
            
            act_next_myr = (act_next_usd * usd_to_myr) / oz_to_g
            pred_next_myr = (pred_next_usd * usd_to_myr) / oz_to_g
            
            err_usd = abs(act_next_usd - pred_next_usd)
            err_myr = (err_usd * usd_to_myr) / oz_to_g
            err_pct = (err_usd / act_next_usd) * 100
            
            dir_act = np.sign(act_next_usd - cur_usd)
            dir_pred = np.sign(pred_next_usd - cur_usd)
            correct_dir = bool(dir_act == dir_pred)
            
            eval_rows.append({
                'date': target_dt_str,
                'actual_usd': round(act_next_usd, 2),
                'pred_usd': round(pred_next_usd, 2),
                'actual_myr': round(act_next_myr, 2),
                'pred_myr': round(pred_next_myr, 2),
                'err_usd': round(err_usd, 2),
                'err_myr': round(err_myr, 2),
                'err_pct': round(err_pct, 2),
                'correct_dir': correct_dir
            })

    df_res = pd.DataFrame(eval_rows)
    print("=" * 60)
    print(" AUGUST 2026 MODEL EVALUATION & ACCURACY REPORT ")
    print("=" * 60)
    print(f" Trading Days Evaluated   : {len(df_res)}")
    print(f" Overall Price Accuracy   : {100 - df_res['err_pct'].mean():.2f}%")
    print(f" MAPE (Mean Error %)      : {df_res['err_pct'].mean():.2f}%")
    print(f" Mean Absolute Error ($)  : ${df_res['err_usd'].mean():.2f} / oz")
    print(f" Mean Absolute Error (RM) : RM {df_res['err_myr'].mean():.2f} / g")
    print(f" Directional Accuracy     : {df_res['correct_dir'].mean() * 100:.1f}%")
    print("=" * 60)
    print("\n--- Day-by-Day Accuracy Breakdown ---")
    for _, r in df_res.iterrows():
        status = "[HIT]" if r['correct_dir'] else "[MISS]"
        print(f" * {r['date']:<17} | Act: RM {r['actual_myr']:>6.2f} (${r['actual_usd']:>7.2f}) | Pred: RM {r['pred_myr']:>6.2f} (${r['pred_usd']:>7.2f}) | Err: RM {r['err_myr']:>5.2f} ({r['err_pct']:>4.2f}%) {status}")
    print("=" * 60)

if __name__ == "__main__":
    eval_august()
