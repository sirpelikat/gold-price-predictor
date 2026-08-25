import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.preprocessing import StandardScaler

# Feature groups
GOLD_GLOBAL_FEATURES = [
    'gold_return_1d', 'gold_return_5d', 'gold_return_10d',
    'gold_ratio_sma_7', 'gold_ratio_sma_14', 'gold_ratio_sma_30', 'gold_ratio_sma_50',
    'gold_macd', 'gold_macd_signal', 'gold_macd_hist',
    'gold_volatility_14', 'gold_volatility_30',
    'gold_rsi_14',
    'dxy_return_1d', 'dxy_return_5d',
    'yield_change_1d', 'yield_change_5d',
    'day_of_week', 'month', 'quarter'
]

FX_MYR_FEATURES = [
    'myr_return_1d', 'myr_return_5d',
    'myr_ratio_sma_7', 'myr_ratio_sma_14', 'myr_ratio_sma_30', 'myr_ratio_sma_50',
    'myr_volatility_14', 'myr_rsi_14',
    'oil_return_1d', 'oil_return_5d', 'oil_ratio_sma_30', 'oil_rsi_14',
    'klci_return_1d', 'klci_return_5d', 'klci_ratio_sma_30', 'klci_rsi_14',
    'dxy_return_1d', 'dxy_return_5d',
    'yield_change_1d', 'yield_change_5d',
    'day_of_week', 'month', 'quarter'
]

DIRECT_MYR_G_FEATURES = [
    'gold_myr_return_1d', 'gold_myr_return_5d',
    'gold_myr_ratio_7', 'gold_myr_ratio_14', 'gold_myr_ratio_30', 'gold_myr_ratio_50',
    'gold_myr_rsi_14',
    'gold_return_1d', 'gold_return_5d', 'gold_rsi_14',
    'myr_return_1d', 'myr_return_5d', 'myr_rsi_14',
    'oil_return_1d', 'oil_return_5d', 'oil_ratio_sma_30',
    'klci_return_1d', 'klci_return_5d', 'klci_ratio_sma_30',
    'dxy_return_1d', 'yield_change_1d',
    'is_pre_hari_raya', 'is_pre_cny', 'is_pre_deepavali', 'is_festive_season',
    'day_of_week', 'month', 'quarter'
]

ALL_FEATURE_COLUMNS = sorted(list(set(GOLD_GLOBAL_FEATURES + FX_MYR_FEATURES + DIRECT_MYR_G_FEATURES)))

class MalaysianMultiTaskGoldEngine:
    """
    Multi-Task Learning Engine for Malaysian Gold Market:
    - Model A: Global XAU/USD Spot Price Predictor
    - Model B: USD/MYR Currency Exchange Rate Predictor
    - Model C: Localized Malaysian Ringgit per Gram (MYR/g) Predictor
    - Combiner: Blends Model A x Model B with Model C to safeguard against currency shocks.
    """
    def __init__(self):
        self.model_gold = HistGradientBoostingRegressor(max_iter=250, max_leaf_nodes=31, learning_rate=0.03, random_state=42)
        self.model_fx = HistGradientBoostingRegressor(max_iter=250, max_leaf_nodes=31, learning_rate=0.03, random_state=42)
        self.model_direct_myr = HistGradientBoostingRegressor(max_iter=250, max_leaf_nodes=31, learning_rate=0.03, random_state=42)
        
        self.scaler_gold = StandardScaler()
        self.scaler_fx = StandardScaler()
        self.scaler_direct = StandardScaler()
        
        self.gold_features = GOLD_GLOBAL_FEATURES
        self.fx_features = FX_MYR_FEATURES
        self.direct_features = DIRECT_MYR_G_FEATURES
        
    def fit(self, df: pd.DataFrame):
        # 1. Train Model A (Global Gold USD Return)
        X_gold = df[self.gold_features].values
        y_gold_ret = df['target_gold_next_return'].values
        X_gold_sc = self.scaler_gold.fit_transform(X_gold)
        self.model_gold.fit(X_gold_sc, y_gold_ret)
        
        # 2. Train Model B (USD/MYR FX Return)
        X_fx = df[self.fx_features].values
        y_fx_ret = df['target_myr_next_return'].values
        X_fx_sc = self.scaler_fx.fit_transform(X_fx)
        self.model_fx.fit(X_fx_sc, y_fx_ret)
        
        # 3. Train Model C (Direct MYR/g Return)
        X_dir = df[self.direct_features].values
        y_dir_ret = df['target_gold_myr_next_return'].values
        X_dir_sc = self.scaler_direct.fit_transform(X_dir)
        self.model_direct_myr.fit(X_dir_sc, y_dir_ret)
        
    def predict_components(self, df_features: pd.DataFrame, cur_gold_usd: float, cur_usd_myr: float):
        troy_oz_to_g = 31.1034768
        cur_myr_g = (cur_gold_usd * cur_usd_myr) / troy_oz_to_g
        
        # Model A prediction (USD)
        x_g = self.scaler_gold.transform(df_features[self.gold_features].values)
        pred_gold_ret = float(self.model_gold.predict(x_g)[0])
        pred_gold_usd = cur_gold_usd * (1.0 + pred_gold_ret)
        
        # Model B prediction (USD/MYR)
        x_fx = self.scaler_fx.transform(df_features[self.fx_features].values)
        pred_fx_ret = float(self.model_fx.predict(x_fx)[0])
        pred_usd_myr = cur_usd_myr * (1.0 + pred_fx_ret)
        
        # Combiner synthesis
        pred_myr_g_mtl = (pred_gold_usd * pred_usd_myr) / troy_oz_to_g
        
        # Model C prediction (Direct localized MYR/g)
        x_dir = self.scaler_direct.transform(df_features[self.direct_features].values)
        pred_dir_ret = float(self.model_direct_myr.predict(x_dir)[0])
        pred_myr_g_dir = cur_myr_g * (1.0 + pred_dir_ret)
        
        # Consensus Ensemble (60% Multi-Task decomposed + 40% Direct localized)
        pred_final_myr_g = (0.60 * pred_myr_g_mtl) + (0.40 * pred_myr_g_dir)
        
        return {
            "predicted_gold_usd": round(pred_gold_usd, 2),
            "predicted_usd_myr": round(pred_usd_myr, 4),
            "predicted_myr_g_mtl": round(pred_myr_g_mtl, 2),
            "predicted_myr_g_direct": round(pred_myr_g_dir, 2),
            "predicted_myr_g_consensus": round(pred_final_myr_g, 2),
            "gold_return_pct": round(pred_gold_ret * 100, 3),
            "myr_return_pct": round(pred_fx_ret * 100, 3)
        }

    def predict_batch(self, df_features: pd.DataFrame):
        troy_oz_to_g = 31.1034768
        cur_gold_usd = df_features['gold_usd'].values
        cur_usd_myr = df_features['usd_myr'].values
        cur_myr_g = (cur_gold_usd * cur_usd_myr) / troy_oz_to_g
        
        # Model A prediction (USD)
        x_g = self.scaler_gold.transform(df_features[self.gold_features].values)
        pred_gold_ret = self.model_gold.predict(x_g)
        pred_gold_usd = cur_gold_usd * (1.0 + pred_gold_ret)
        
        # Model B prediction (USD/MYR)
        x_fx = self.scaler_fx.transform(df_features[self.fx_features].values)
        pred_fx_ret = self.model_fx.predict(x_fx)
        pred_usd_myr = cur_usd_myr * (1.0 + pred_fx_ret)
        
        # Combiner synthesis
        pred_myr_g_mtl = (pred_gold_usd * pred_usd_myr) / troy_oz_to_g
        
        # Model C prediction (Direct localized MYR/g)
        x_dir = self.scaler_direct.transform(df_features[self.direct_features].values)
        pred_dir_ret = self.model_direct_myr.predict(x_dir)
        pred_myr_g_dir = cur_myr_g * (1.0 + pred_dir_ret)
        
        # Consensus Ensemble (60% Multi-Task decomposed + 40% Direct localized)
        pred_final_myr_g = (0.60 * pred_myr_g_mtl) + (0.40 * pred_myr_g_dir)
        
        return {
            "predicted_gold_usd": pred_gold_usd,
            "predicted_usd_myr": pred_usd_myr,
            "predicted_myr_g_consensus": pred_final_myr_g
        }
