# 🥇 Malaysian Gold Intelligence Model & Price Predictor

A production-grade, specialized machine learning platform and cross-platform mobile/web application tailored for the **Malaysian gold market**. It models the dual forces governing Malaysian gold prices—**Global Gold Value ($\text{USD/oz}$)** and **Malaysian Ringgit FX ($\text{USD/MYR}$)**—integrating local macroeconomic indicators, Bank Negara Malaysia (BNM) Kijang Emas retail spreads, and Malaysian festive seasonality.

---

## 🚀 Key Features

### 1. 🇲🇾 Malaysian Market Specialization
- **Synthesized $\text{MYR/g}$ Target**: Evaluates gold directly in Ringgit per gram using the official conversion:
  $$\text{Gold Price (MYR/g)} = \frac{\text{Gold USD Price (GC=F)} \times \text{USD/MYR Rate (USDMYR=X)}}{31.1034768}$$
- **🪙 BNM Kijang Emas Physical Bullion Spread**: Live integration with the **Bank Negara Malaysia Open API** (`/public/kijang-emas`) to display official Maybank bullion selling/buying rates and physical retail spreads (+4.10% over paper spot).
- **🛢️ Macroeconomic Drivers**: Incorporates **Brent Crude Oil (`BZ=F`)** (petroleum export revenue $\rightarrow$ Ringgit strength), **FBM KLCI (`^KLSE`)** (local market sentiment), and **BNM Overnight Policy Rate (2.75% OPR)**.
- **🎉 Malaysian Festive Seasonality**: Features 30-day pre-festival indicator flags for **Hari Raya Aidilfitri**, **Chinese New Year**, and **Deepavali** (2010–2030) to capture local physical buying surges.

### 2. 🧠 Multi-Task Learning (MTL) Dual-Engine Architecture
- **Model A (Global Gold Engine)**: Predicts $\Delta \text{Gold}_{\text{USD/oz}}$ driven by 10Y US Treasury yields (`^TNX`), US Dollar Index (`DX-Y.NYB`), and global volatility.
- **Model B (Currency FX Engine)**: Predicts $\Delta \text{USD/MYR}$ driven by Brent Oil, FBM KLCI, and BNM OPR.
- **Model C (Localized MYR/g Engine)**: Predicts $\Delta \text{Gold}_{\text{MYR/g}}$ directly with Malaysian festive seasonality.
- **Ensemble Combiner**: Blends Model A $\times$ Model B with Model C (60:40) to safeguard against currency shocks.

### 3. 🛡️ MLOps Automated Retraining & Promotion Gate
- **Expanding-Window Walk-Forward Validation**: Evaluates models across 5 sequential chronological folds (`TimeSeriesSplit`) without future data leakage.
- **The Promotion Gate**: Safety checks candidate validation metrics (MAPE $\le 1.50\%$, MAE within tolerance) before deployment.
- **Model Versioning & Hot-Swap**: Promoted models are archived in `backend/models/archive/` and swapped in-memory with zero server downtime.
- **CI/CD Cloud Retraining**: [`.github/workflows/scheduled_retraining.yml`](.github/workflows/scheduled_retraining.yml) automatically executes monthly cloud retraining on GitHub Actions.

### 4. 🔒 8:00 AM Daily Snapshot & Continuous Audit Trail
- **8:00 AM Daily Snapshot Policy**: Daily forward predictions are permanently snapshotted and locked every morning at 8:00 AM.
- **Auto-Sync Reconciliation**: Daily predictions are matched against official Yahoo Finance settlement closes with error tracking.
- **Interactive Log Filters**: Filter historical logs by `[ All ]`, `[ Verified ]`, and `[ Pending ]` with market close countdown badges.

### 5. 📱 Premium Cross-Platform Mobile Dashboard
- **Global Currency Switcher**: Instant conversion across the app between **`MYR / g`** and **`USD / oz`**.
- **Segmented Timeframe Selectors**: Interactive **`7D`** (Weekly), **`1M`** (Monthly), and **`1Y`** (Annual) views.
- **Dual-Line Comparison Chart**: Solid blue line (Actual Market Close) vs Dashed amber line (Model Prediction).

---

## 📊 Model Performance & Benchmarks

### 2025 Out-of-Sample Benchmark (259 Trading Days)
| Metric | Malaysian Multi-Task Engine | Global Baseline |
| :--- | :---: | :---: |
| **Malaysian Gold (MYR/g) MAE** | **RM 4.70 / g** | RM 5.07 / g |
| **Malaysian Gold (MYR/g) MAPE** | **0.97%** (**99.03% Accuracy**) | 1.00% |
| **Global Gold (USD/oz) MAE** | **$34.14 / oz** | $35.43 / oz |
| **Goodness of Fit ($R^2$)** | **0.9854** | 0.9895 |
| **Directional Accuracy** | **52.51%** | 48.41% |

### 5-Fold Walk-Forward Cross-Validation (2010 – 2026)
| Fold | Period | Samples | MAE (MYR/g) | MAE (USD/oz) | Fold MAPE (%) |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Fold 1** | 2012-12 to 2015-09 | 714 | **RM 1.22 / g** | $10.80 / oz | 0.88% |
| **Fold 2** | 2015-09 to 2018-06 | 714 | **RM 1.27 / g** | $8.22 / oz | 0.76% |
| **Fold 3** | 2018-06 to 2021-02 | 714 | **RM 1.55 / g** | $11.26 / oz | 0.73% |
| **Fold 4** | 2021-02 to 2023-11 | 714 | **RM 1.86 / g** | $12.83 / oz | 0.72% |
| **Fold 5** | 2023-11 to 2026-08 | 714 | **RM 4.87 / g** | $34.85 / oz | 1.02% |
| **Average** | **Full 14-Year Timeline** | **3,570** | **RM 2.15 / g** | **$15.59 / oz** | **0.82% (99.18% Accuracy)** |

---

## 🛠️ Tech Stack

### **Backend**
- **Language**: Python 3.12+
- **Framework**: FastAPI + Uvicorn
- **Data Providers**: `yfinance` (`GC=F`, `USDMYR=X`, `BZ=F`, `^KLSE`, `^TNX`, `DX-Y.NYB`), Bank Negara Malaysia (BNM) Open API
- **Machine Learning**: `scikit-learn` (`HistGradientBoostingRegressor`), `pandas`, `numpy`, `joblib`

### **Mobile App**
- **Framework**: Flutter (Dart 3+)
- **Networking**: `http` package
- **Visualization**: `fl_chart`

---

## 📁 Project Structure

```text
gold-price-predictor/
├── backend/
│   ├── data/
│   │   ├── gold_train_2010_2024.csv    # 2010–2024 training dataset (79 features)
│   │   ├── gold_test_2025.csv          # 2025 out-of-sample test dataset
│   │   ├── gold_master_timeline.csv    # Complete master timeline
│   │   └── eval_results_2025.csv       # Actual vs predicted 2025 comparison
│   ├── data_sources/
│   │   └── bnm_client.py               # Bank Negara Malaysia (BNM) Open API client
│   ├── models/
│   │   ├── archive/                    # Archived versioned models (rollback registry)
│   │   └── model_registry.json         # Production version & gate evaluation history
│   ├── logs/
│   │   ├── prediction_history.csv      # Daily prediction audit trail & reconciliations
│   │   └── model_performance_log.json  # Cumulative error distributions & metrics
│   ├── data_fetcher.py                 # Real-time multi-asset market data fetcher
│   ├── prepare_datasets.py             # Feature engineering, macro synthesis & festival calendar
│   ├── engine.py                       # MalaysianMultiTaskGoldEngine architecture definition
│   ├── train.py                        # Model training pipeline
│   ├── evaluate.py                     # Out-of-sample evaluation runner
│   ├── retraining_pipeline.py          # Walk-forward CV, promotion gate & hot-swapper
│   ├── model.py                        # Multi-step inference engine & hot-reloader
│   ├── gold_model.joblib               # Active production model artifact
│   ├── main.py                         # FastAPI REST API server
│   └── requirements.txt                # Python dependencies
│
├── mobile_app/
│   ├── lib/
│   │   ├── main.dart                   # App entry point & theme
│   │   ├── screens/
│   │   │   └── dashboard.dart          # Multi-tab dashboard (Forecast, Model Analysis, Daily Logs)
│   │   └── services/
│   │       └── api_service.dart        # REST client & auto-host resolution (Android/Web/Desktop)
│   └── pubspec.yaml                    # Flutter dependencies
│
└── .github/
    └── workflows/
        └── scheduled_retraining.yml    # Monthly CI/CD automated retraining workflow
```

---

## 🏁 Quick Start

### 1. Prerequisites
- [Python 3.10+](https://www.python.org/downloads/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)

### 2. Set Up & Run Backend
```bash
cd backend
python -m venv venv

# Windows (PowerShell):
.\venv\Scripts\Activate.ps1
# Mac/Linux:
# source venv/bin/activate

pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

> **API Documentation**: Visit `http://127.0.0.1:8000/docs` to test endpoints via Swagger UI.

### 3. Set Up & Run Mobile App
```bash
cd mobile_app
flutter pub get
flutter run
```

---

## 📡 API Endpoints

| Endpoint | Method | Description |
| :--- | :---: | :--- |
| `/api/current-price` | `GET` | Live paper spot price (`MYR/g`, `USD/oz`) and BNM Kijang Emas physical retail rates & spread |
| `/api/malaysia-macro` | `GET` | Live Malaysian macro indicators (Brent Oil, FBM KLCI, BNM OPR, festive demand status) |
| `/api/historical?days=N` | `GET` | Historical dual-line prices (`price`, `price_usd`, `predicted_price`, `predicted_price_usd`) for 7, 30, or 365 days |
| `/api/prediction?days=N` | `GET` | Multi-step forward AI price projections (`price` in MYR/g, `price_usd` in USD/oz) |
| `/api/model-metrics` | `GET` | Model training metadata and 2025 out-of-sample test benchmark metrics |
| `/api/prediction-logs` | `GET` | Complete historical audit trail with daily prediction vs actual market closes and error variances |
| `/api/prediction-logs/sync` | `POST` | Triggers background reconciliation of pending predictions against market settlement closes |
| `/api/retraining-status` | `GET` | Current production version, last retrained timestamp, and historical promotion gate logs |
| `/api/retrain` | `POST` | Triggers walk-forward cross-validation retraining, promotion gate, and in-memory model hot-swap |

---

## 📝 License
This project is open-source and available under the [MIT License](LICENSE).
