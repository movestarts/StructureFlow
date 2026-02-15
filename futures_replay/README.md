# Futures Replay (K线训练营)

A professional Futures K-Line Replay and Trading Simulation application built with **Flutter**.

![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue)
![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## 📖 Introduction

**Futures Replay** is a powerful tool designed for traders to practice and refine their trading strategies using historical data. It allows you to replay market data at variable speeds, simulate trades (Long/Short), and analyze your performance with detailed statistics.

Key features include customized K-line periods, technical indicators (MACD, BOLL, RSI, etc.), and persistent trade history.

## ✨ Features

- **K-Line Replay**: Replay historical data with adjustable speeds and pause/resume functionality.
- **Multi-Period Support**: seamlessly switch between 5m, 15m, 30m, 1H, 4H, and 1D timeframes.
- **Simulation Trading**:
  - Open Long/Short positions.
  - Real-time PnL (Profit and Loss) calculation.
  - Leverage adjustment.
- **Technical Indicators**: 
  - Main Chart: MA, EMA, BOLL.
  - Sub Chart: Volume, MACD, KDJ, RSI, WR.
- **Data Management**:
  - Import CSV data.
  - High-performance data caching using **Isar Database**.
- **Performance Analysis**:
  - Detailed trade history.
  - Win rate, Total PnL, and ROI statistics.
  - Visual review of past trades on the chart.

## 🛠 Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Language**: [Dart](https://dart.dev/)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Local Database**: [Isar](https://isar.dev/) (NoSQL)
- **Charting**: Custom `CustomPaint` based rendering for high performance.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Git installed.

### Installation

1.  **Clone the repository**
    ```bash
    git clone https://github.com/Start-Trading-App/futures_replay.git
    cd futures_replay
    ```

2.  **Install dependencies**
    ```bash
    flutter pub get
    ```

3.  **Run the app**
    ```bash
    # For Windows
    flutter run -d windows
    
    # For Android
    flutter run -d android
    ```

## 📂 Project Structure

```
lib/
├── engine/          # Replay and Trade core logic
├── models/          # Data models (Kline, TradeRecord, etc.)
├── services/        # Data services (Database, Account, Calculation)
├── ui/
│   ├── chart/       # Custom chart painters
│   ├── screens/     # Application screens (Main, Setup, History)
│   ├── theme/       # App styling and colors
│   └── widgets/     # Reusable widgets
└── main.dart        # Entry point
```

## 📝 Usage

1.  **Setup**: Launch the app and select your historical CSV data file.
2.  **Configure**: Choose your initial timeframe (e.g., 5m, 30m) and start date.
3.  **Trade**: Use the control panel to Play/Pause the replay. Click "Long" or "Short" to enter trades.
4.  **Review**: After the session, go to "Trade History" to review your performance and analyze individual trades on the chart.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
