# 📱 Malaysian Gold AI Tracker (Flutter App)
 
 A cross-platform mobile and web application engineered with Flutter to deliver real-time gold tracking, AI-powered multi-step forecasting, and macroeconomic intelligence tailored for the Malaysian market.

---

## ✨ Features & Interface

### 1. 🎨 Apple-Style Liquid Glass UI
* **Translucent Blur**: Uses dynamic `BackdropFilter` and gradient borders to render frosted glass components.
* **Ambient Lighting Glow**: Ambient background radiant glow orbs that respond smoothly to theme changes.

### 2. 🔀 Casual vs Pro Experience Modes
* **Casual Mode**: Minimalist, card-based interface focused on key insights:
  * Live spot price in **RM / g** or **USD / oz**.
  * AI Verdict capsule with expected trend direction.
  * 7-day projection sparkline.
  * Maybank Kijang Emas physical retail buy/sell spread.
* **Pro Mode**: In-depth analytical workstation containing:
  * **Forecast Tab**: Multi-step forward trajectories (`7D`, `30D`, `365D`) with statistical variance bounds.
  * **MLOps & Macro Tab**: Real-time cross-validation metrics, feature importance, macro drivers (Brent Oil, FBM KLCI, BNM OPR), and one-tap model retraining.
  * **Daily Logs Tab**: Continuous audit trail comparing past model forecasts against official market closes.

### 3. 💱 Global Currency Switcher
* One-tap instant toggle between **`MYR / g`** (Malaysian Ringgit per gram) and **`USD / oz`** (US Dollars per troy ounce).

### 4. 🌐 Auto-Host Network Resolution
* Built-in dynamic host routing:
  * **Android Emulator**: Resolves to `http://10.0.2.2:8000/api`
  * **Web / Desktop / Localhost**: Resolves to `http://127.0.0.1:8000/api`

---

## 🚀 Running the App

### Prerequisites
* Flutter SDK (3.0+)
* Android Studio / VS Code with Flutter extensions
* Backend server running at `http://127.0.0.1:8000`

### Commands
```bash
# 1. Install dependencies
flutter pub get

# 2. Run on Android emulator / connected device
flutter run

# 3. Run on Chrome (Web)
flutter run -d chrome
```

---

## 🔧 Emulator Troubleshooting

### Black Screen on Android Emulator
If the emulator device boots up but the Flutter app displays a solid black or dark screen:

1. **Disable Impeller (Vulkan fallback to OpenGL)**:
   ```bash
   flutter run --no-enable-impeller
   ```
2. **Cold Boot the Emulator**:
   * Open Android Studio $\rightarrow$ **Device Manager** $\rightarrow$ Click `...` $\rightarrow$ Select **Cold Boot Now** (or **Wipe Data**).
3. **Change Emulator Graphics Renderer**:
   * In Device Manager, edit device $\rightarrow$ **Show Advanced Settings** $\rightarrow$ Change **Graphics** to **Software - GLES 2.0**.
