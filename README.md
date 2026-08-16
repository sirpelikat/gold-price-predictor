# 🥇 Gold Price Tracker & Predictor

A cross-platform mobile and web application that tracks real-time gold prices in **Malaysian Ringgit (MYR/g)**, visualizes historical price trends, and leverages Machine Learning to forecast short-term future gold prices.

---

## 🚀 Features

- 📈 **Live Gold Price Tracking**: Real-time gold price fetching from Yahoo Finance (`GC=F` futures) converted automatically to **MYR per gram** using live USD/MYR exchange rates.
- 📊 **Past 7 Days Trend**: Interactive historical price chart powered by `fl_chart`.
- 🤖 **AI Price Forecasting**: Machine Learning model predicting the next 7 days of gold prices based on short-term market momentum.
- 📱 **Cross-Platform**: Built with **Flutter** (Android, Web/Chrome, Windows Desktop) and a **FastAPI** backend.
- 🌐 **Automatic Host Detection**: Dynamically switches backend endpoints for Android emulators (`10.0.2.2`) and Web/Desktop environments (`127.0.0.1`).

---

## 🛠️ Tech Stack

### **Backend**
- **Language**: Python 3.12+
- **Framework**: FastAPI + Uvicorn
- **Data Source**: `yfinance` (Gold Futures `GC=F`, USD/MYR `USDMYR=X`)
- **Machine Learning**: `scikit-learn` (`HistGradientBoostingRegressor`, `RandomForestRegressor`), `pandas`, `joblib`

### **Mobile App**
- **Framework**: Flutter (Dart)
- **State & Networking**: `http` package
- **Charts**: `fl_chart`

---

## 📁 Project Structure

```text
gold-price-predictor/
├── backend/
│   ├── data/
│   │   ├── gold_train_2010_2024.csv  # 2010–2024 training dataset (3,771 rows, 35 features)
│   │   ├── gold_test_2025.csv        # 2025 out-of-sample test dataset (252 rows)
│   │   └── eval_results_2025.csv     # Actual vs predicted 2025 comparison
│   ├── data_fetcher.py               # Fetches live gold prices & exchange rates via yfinance
│   ├── prepare_datasets.py           # Dataset generation & feature engineering pipeline
│   ├── train.py                      # Model training & hyperparameter selection
│   ├── evaluate.py                   # Out-of-sample 2025 accuracy benchmark evaluation
│   ├── model.py                      # Multi-day recursive forecasting inference engine
│   ├── gold_model.joblib             # Serialized production model artifact
│   ├── main.py                       # FastAPI REST API server
│   └── requirements.txt              # Python dependencies
│
└── mobile_app/
    ├── lib/
    │   ├── main.dart                 # App entry point
    │   ├── screens/
    │   │   └── dashboard.dart        # Dashboard UI with live price & charts
    │   └── services/
    │       └── api_service.dart      # Cross-platform API service client
    ├── android/                      # Android project configuration & manifest
    └── pubspec.yaml                  # Flutter dependencies
```

---

## 🤖 Machine Learning Pipeline & Accuracy

### Datasets
- **Training Set (`2010–2024`)**: 3,771 trading days with technical indicators (RSI 14, MACD, SMAs 7/14/30/50, EMAs, 14d/30d Volatility, Day/Month seasonality, Lag returns).
- **Test Set (`2025`)**: 252 out-of-sample trading days.

### 2025 Out-of-Sample Test Benchmark
| Metric | Value |
| :--- | :--- |
| **Model** | `HistGradientBoostingRegressor` |
| **Mean Absolute Error (MAE)** | **$35.43 / oz** (~ **RM 5.07 / g**) |
| **MAPE (Mean Error %)** | **1.00%** |
| **R² Score** | **0.9895** |

### Running the Pipeline
```bash
# 1. Download and build datasets (2010-2024 train, 2025 test)
python prepare_datasets.py

# 2. Train the model
python train.py

# 3. Evaluate against 2025 actuals
python evaluate.py
```

---

## 🏁 Quick Start

### 1. Prerequisites
- [Python 3.10+](https://www.python.org/downloads/) installed
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed
- Android Emulator, Chrome, or Windows Desktop enabled for Flutter

---

### 2. Set Up & Run the Backend

```bash
# Navigate to backend directory
cd backend

# Create virtual environment
python -m venv venv

# Activate virtual environment
# Windows (PowerShell):
.\venv\Scripts\Activate.ps1
# Mac/Linux:
# source venv/bin/activate

# Install dependencies
pip install fastapi uvicorn yfinance scikit-learn pandas joblib

# Run the FastAPI server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

> **API Documentation**: Once running, visit `http://127.0.0.1:8000/docs` to test endpoints via Swagger UI.

---

### 3. Set Up & Run the Mobile App

Open a new terminal window:

```bash
# Navigate to mobile app directory
cd mobile_app

# Get Flutter dependencies
flutter pub get

# Run on Android Emulator, Chrome, or Desktop
flutter run
```

---

## 📡 API Endpoints

| Endpoint | Method | Description |
| :--- | :--- | :--- |
| `/` | `GET` | API Health Check |
| `/api/current-price` | `GET` | Returns live gold price in MYR/g and MYR/kg |
| `/api/historical?days=7` | `GET` | Returns historical gold prices for specified days |
| `/api/prediction` | `GET` | Returns AI predicted gold prices and logs them automatically |
| `/api/model-metrics` | `GET` | Returns ML model training & 2025 test evaluation metrics |
| `/api/prediction-logs` | `GET` | Returns historical logged predictions, errors, and running accuracy |
| `/api/prediction-logs/sync`| `POST` | Syncs actual prices with past predictions to recalculate accuracy |

---

## 📝 License

This project is open-source and available under the [MIT License](LICENSE).
