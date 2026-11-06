# 📈 StockBar

A lightweight, native macOS menu bar application designed for Indian stock market swing traders. Track your active holdings, real-time prices, and live P&L at a glance right from your menu bar without opening Zerodha Kite or browser tabs.

---

## ✨ Features

- **Live Menu Bar Badge:** Displays your overall Day P&L dynamically in the top menu bar (e.g. `📈 +₹1,245.50` or `📉 -₹320.00`).
- **Floating Movable Window:** Click the menu bar badge to toggle a sleek, floating window. Drag and place it anywhere across your screens; it stays visible even while interacting with other applications.
- **Google Sheets Sync:** Syncs directly with your existing Google Sheet tracking swing trades. Automatically identifies active positions by filtering out completed/closed trades.
- **Hybrid Real-Time Pricing:** Pulls live price updates and previous close data from Yahoo Finance while seamlessly falling back to Google Sheet formulas (`GOOGLEFINANCE`) when offline or during rate limits.
- **Color-Coded Positions:** Profit/loss color highlights (green/red) with strict 2-decimal formatting across all currency and percentage figures.
- **Configurable Auto-Refresh:** Automatically refreshes quotes every 10s, 30s, 1m, or 5m.
- **Auto Launch at Login:** Seamlessly starts when your Mac boots.

---

## 🏗️ Architecture

- **Language & Framework:** Swift 5.9+ / SwiftUI & AppKit
- **Packaging:** Swift Package Manager (no heavy Xcode dependencies needed to build)
- **Data Pipeline:**
  ```
  Google Sheets (CSV Export) ──▶ Sheet Parser (RFC 4180)
                                      │
  Yahoo Finance v8 Chart API ──▶ Quote Service (Concurrent async/await)
                                      │
                                      ▼
                               PortfolioViewModel
                                      │
                        ┌─────────────┴─────────────┐
                        ▼                           ▼
                 NSStatusBar Item             Floating NSWindow
                 (Day P&L Badge)             (Holdings & Breakdown)
  ```

---

## 🚀 Quick Start

### 1. Build & Run

Clone the repository and build using the provided script:

```bash
git clone https://github.com/Mosam219/StockBar.git
cd StockBar
./build.sh
open StockBar.app
```

Or build manually via Swift Package Manager:

```bash
swift build -c release
mkdir -p StockBar.app/Contents/MacOS
cp .build/release/StockBar StockBar.app/Contents/MacOS/StockBar
open StockBar.app
```

### 2. Connect Your Google Sheet

1. Click the **📈 StockBar** icon in your menu bar.
2. Click the **⚙️ Settings** icon in the footer.
3. Paste your Google Sheet URL (supports standard sharing links like `https://docs.google.com/spreadsheets/d/.../edit?usp=sharing`).
4. Choose your preferred refresh interval and click **Save & Refresh**.

---

## 📊 Expected Google Sheet Format

StockBar expects the standard column headers in your trade log:

| stock symbol | qty | buy price | current price | today up | sell |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `DRREDDY` | `10` | `1199.10` | `1373.00` | `0.51%` | *(empty)* |
| `BSE` | `4` | `3541.00` | `3800.00` | `0.26%` | *(empty)* |
| `BEL` | `24` | `412.50` | `396.00` | `0.23%` | `405.35` |

> [!NOTE]
> - Rows with an **empty `sell` column** are treated as **active holdings**.
> - Rows with a filled `sell` column are treated as closed trades and skipped.
> - Comma-separated numbers (e.g. `"1,250.00"`) and currency symbols (`₹`) are automatically parsed and sanitized.

---

## ⚙️ Start Automatically on Mac Boot

To have StockBar launch every time you log in to your Mac:

```bash
osascript -e 'tell application "System Events" to make login item at end with properties {name:"StockBar", path:"'"$(pwd)"'/StockBar.app", hidden:false}'
```

You can verify or toggle this at any time in **System Settings → General → Login Items**.

---

## 🛠️ Project Structure

```
StockBar/
├── Package.swift               # Swift Package manifest
├── build.sh                    # Build and bundle script
├── .gitignore                  # Git ignore rules
├── README.md                   # Project documentation
├── StockBar.app/               # Native macOS App wrapper
│   └── Contents/
│       └── Info.plist          # App metadata & LSUIElement agent config
└── Sources/
    └── StockBar/
        ├── StockBarApp.swift        # App entry point, NSStatusItem & NSWindow setup
        ├── Models.swift             # Data models & Codable definitions
        ├── GoogleSheetsService.swift# Robust CSV parsing & URL conversion
        ├── StockService.swift       # Async concurrent Yahoo Finance quote fetching
        ├── PortfolioViewModel.swift # State orchestration & currency formatting
        ├── HoldingsView.swift       # Main SwiftUI floating window interface
        └── SettingsView.swift       # Sheet URL & auto-refresh settings popover
```

---

## 📄 License

MIT License. Free to use and customize for personal trading needs.
