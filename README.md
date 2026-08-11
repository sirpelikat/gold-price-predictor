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
- **Machine Learning**: `scikit-learn` (Linear Regression), `pandas`

### **Mobile App**
- **Framework**: Flutter (Dart)
- **State & Networking**: `http` package
- **Charts**: `fl_chart`

---

## 📁 Project Structure

```text
gold-price-predictor/
├── backend/
│   ├── data_fetcher.py   # Fetches live gold prices & exchange rates via yfinance
│   ├── model.py          # Machine learning model for 7-day trend forecasting
│   ├── main.py           # FastAPI REST API server
│   └── requirements.txt  # Python dependencies
│
└── mobile_app/
    ├── lib/
    │   ├── main.dart             # App entry point
    │   ├── screens/
    │   │   └── dashboard.dart    # Dashboard UI with live price & charts
    │   └── services/
    │       └── api_service.dart  # Cross-platform API service client
    ├── android/                  # Android project configuration & manifest
    └── pubspec.yaml              # Flutter dependencies
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
pip install fastapi uvicorn yfinance scikit-learn pandas

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
| `/api/prediction` | `GET` | Returns AI predicted gold prices for next 7 days |

---

## 📝 License

This project is open-source and available under the [MIT License](LICENSE).
