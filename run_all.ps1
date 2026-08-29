# Run all services (FastAPI Backend + Flutter App) in separate PowerShell processes
$rootDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "  Starting Gold Price Predictor (Full-Stack)" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan

# 0. Check and clear port 8000 if occupied by a stale process
$stalePort = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
if ($stalePort) {
    Write-Host "Clearing existing process on Port 8000 (PID: $stalePort)..." -ForegroundColor Magenta
    Stop-Process -Id $stalePort -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
}

# 1. Start Backend in new window
Write-Host "[1/2] Launching Backend FastAPI Server (Port 8000)..." -ForegroundColor Yellow
$backendCmd = "Set-Location '$rootDir\backend'; if (Test-Path '.\venv\Scripts\uvicorn.exe') { .\venv\Scripts\uvicorn.exe main:app --host 0.0.0.0 --port 8000 --reload } else { uvicorn main:app --host 0.0.0.0 --port 8000 --reload }"
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $backendCmd

# 2. Start Flutter App in new window
Write-Host "[2/2] Launching Flutter App..." -ForegroundColor Yellow
$flutterCmd = "Set-Location '$rootDir\mobile_app'; flutter run"
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-Command", $flutterCmd

Write-Host "===================================================" -ForegroundColor Green
Write-Host "Both Backend & Frontend are now launching!" -ForegroundColor Green
Write-Host "Swagger API Docs: http://localhost:8000/docs" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
