# Futures Replay (期货复盘训练系统)

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 📖 简介

**Futures Replay** 是一个基于 **Flutter** 开发的专业期货 K 线回放与模拟交易系统。它专为交易员设计，帮助用户利用历史数据进行实战演练，验证交易策略，并提供详细的绩效分析和 AI 智能复盘功能。

通过本系统，您可以像播放视频一样回放历史行情，随时暂停、加速，并进行模拟开平仓操作，从而在零风险的环境下积累实战经验。

## ✨ 核心功能
<img width="1543" height="853" alt="image" src="https://github.com/user-attachments/assets/3c34d89a-546f-4e42-bbfc-3d3c6c69850e" />

### 1. K 线回放 (K-Line Replay)
*   **多周期支持**：支持 1分钟、5分钟、15分钟、30分钟、1小时、4小时、1天等多种周期切换。
*   **变速播放**：可调节回放速度，支持暂停、步进（下一根 K 线）操作。
*   **流畅体验**：基于 CustomPaint 的高性能绘图引擎，保证大量数据下的流畅渲染。

### 2. 模拟交易 (Simulation Trading)
*   **全功能交易**：支持开多 (Long)、开空 (Short)、平仓操作。
*   **资金管理**：实时计算浮动盈亏 (PnL)、权益 (Equity) 和 收益率 (ROI)。
*   **杠杆调节**：支持自定义杠杆倍数。
*   **持仓管理**：实时查看当前持仓状态、均价及未实现盈亏。

### 3. AI 智能复盘 (AI Smart Review) 🤖
*   **LLM 集成**：内置 LangChain 支持，可连接大语言模型（如 OpenAI、Claude 等）。
*   **交易分析**：AI 根据您的交易记录自动生成分析报告，指出交易中的优缺点。
*   **个性化配置**：支持管理不同的 LLM 模型配置和 Prompt 模板。

### 4. 技术指标 (Technical Indicators)
*   **主图指标**：移动平均线 (MA)、指数移动平均线 (EMA)、布林带 (BOLL)。
*   **副图指标**：成交量 (Volume)、MACD、KDJ、RSI、WR。
*   **自定义参数**：支持调整各项指标的计算参数。

### 5. 数据管理 (Data Management)
*   **数据导入**：支持导入标准 CSV 格式的历史行情数据。
*   **本地存储**：使用高性能 **Isar** 数据库进行本地缓存，确保快速加载和离线使用。
*   **数据维护**：提供数据清理和管理界面，轻松管理历史数据。

### 6. 绩效分析与工具 (Performance & Tools)
*   **详细记录**：自动记录每一笔交易的开平仓时间、价格、盈亏等信息。
*   **图表复盘**：在 K 线图上可视化展示历史交易点位，方便复盘分析。
*   **统计报表**：自动计算胜率、盈亏比、最大回撤等关键指标。
*   **仓位计算器**：内置仓位计算工具，辅助制定资金管理计划。
*   **快捷键支持**：支持自定义快捷键，提升操作效率。

## 🛠 技术栈

*   **框架**: [Flutter](https://flutter.dev/) (UI 构建)
*   **语言**: [Dart](https://dart.dev/)
*   **状态管理**: [Provider](https://pub.dev/packages/provider)
*   **本地数据库**: [Isar](https://isar.dev/) (高性能 NoSQL 数据库)
*   **AI 框架**: [LangChain](https://pub.dev/packages/langchain) (大模型集成)
*   **图表引擎**: CustomPaint (自定义高性能绘图)
*   **文件处理**: CSV, file_picker

## 🚀 快速开始

### 环境要求

*   [Flutter SDK](https://docs.flutter.dev/get-started/install) (推荐最新稳定版)
*   Git

### 安装步骤

1.  **克隆项目**
    ```bash
    git clone https://github.com/Start-Trading-App/futures_replay.git
    cd futures_replay
    ```

2.  **安装依赖**
    ```bash
    flutter pub get
    ```

3.  **生成代码 (如果使用了 build_runner)**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```

4.  **运行应用**
    ```bash
    # Windows
    flutter run -d windows
    
    # Android
    flutter run -d android
    
    # macOS
    flutter run -d macos
    ```

## 📂 项目结构

```
lib/
├── engine/          # 回放与交易核心逻辑引擎
├── models/          # 数据模型 (K线, 交易记录, AI配置等)
├── services/        # 核心服务 (数据库, 账户服务, AI服务, 数据处理)
├── ui/
│   ├── chart/       # 自定义图表绘制 (Painter)
│   ├── screens/     # 应用页面 (主界面, 设置, 历史记录, AI配置等)
│   ├── theme/       # 主题样式与颜色定义
│   └── widgets/     # 通用 UI 组件
├── utils/           # 工具类
└── main.dart        # 程序入口
```

## 📝 使用指南

1.  **数据准备**：启动应用，进入“导入数据”页面，选择您的 CSV 历史数据文件导入。
2.  **初始化设置**：选择初始资金、杠杆倍数、回放起始时间及 K 线周期。
3.  **开始回放**：点击播放按钮开始回放行情。使用控制面板调整速度或暂停。
4.  **模拟交易**：根据行情判断，点击“买入/做多”或“卖出/做空”。
5.  **复盘分析**：交易结束后，进入“交易历史”查看详细记录，或使用“AI 复盘”获取智能建议。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目！

## 📄 许可证

本项目采用 MIT 许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

Let's start!
