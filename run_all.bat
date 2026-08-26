@echo off
echo ===================================================
echo   Starting Gold Price Predictor (Full-Stack)
echo ===================================================

echo [1/2] Launching Backend FastAPI Server (Port 8000)...
start "Gold Price Predictor - Backend" cmd /k "cd /d %~dp0backend && call venv\Scripts\activate.bat && uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

echo [2/2] Launching Flutter App...
start "Gold Price Predictor - Mobile/Frontend" cmd /k "cd /d %~dp0mobile_app && flutter run"

echo ===================================================
echo Backend & Frontend launched in separate windows!
echo Backend API Docs: http://localhost:8000/docs
echo ===================================================
