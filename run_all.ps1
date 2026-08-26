# Run all services (FastAPI Backend + Flutter App) in separate PowerShell processes
$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Starting Gold Price Predictor (Full-Stack)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 1. Start Backend in new window
Write-Host "[1/2] Launching Backend FastAPI Server (Port 8000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$rootDir\backend'; if (Test-Path '.\venv\Scripts\Activate.ps1') { .\venv\Scripts\Activate.ps1 }; uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

# 2. Start Flutter App in new window
Write-Host "[2/2] Launching Flutter App..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$rootDir\mobile_app'; flutter run"

Write-Host "===================================================" -ForegroundColor Green
Write-Host "Both Backend & Frontend are now running!" -ForegroundColor Green
Write-Host "Swagger API Docs: http://localhost:8000/docs" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
