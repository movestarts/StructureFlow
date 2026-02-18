# Futures Replay (期货复盘训练系统)

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0%2B-blue)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

## 📖 简介

**Futures Replay** 是一个基于 **Flutter** 开发的专业期货 K 线回放与模拟交易系统。它专为交易员设计，帮助用户利用历史数据进行实战演练，验证交易策略，并提供详细的绩效分析和 AI 智能复盘功能。

通过本系统，您可以像播放视频一样回放历史行情，随时暂停、加速，并进行模拟开平仓操作，从而在零风险的环境下积累实战经验。

## ✨ 核心功能

### 1. K 线回放 (K-Line Replay)
*   **多周期支持**：支持 1分钟、5分钟、15分钟、30分钟、1小时、4小时、1天等多种周期切换。
*   **双推进模式** 🆕：
    - **按周期推进**：快速跳跃式回放，快速浏览行情走势
    - **按源K线推进**：连续式回放，观察K线逐根形成过程
*   **变速播放**：可调节回放速度（50ms-2000ms），支持暂停、步进操作。
*   **鼠标滚轮缩放** 🆕：像券商软件一样，滚轮缩放K线宽度，查看不同细节层次。
*   **流畅体验**：基于 CustomPaint 的高性能绘图引擎，保证大量数据下的流畅渲染。

### 2. 模拟交易 (Simulation Trading)
*   **全功能交易**：支持开多 (Long)、开空 (Short)、平仓操作。
*   **快速训练模式** 🆕：随机合约训练 - 一键开始，无需配置，随机品种和时间。
*   **资金管理**：实时计算浮动盈亏 (PnL)、权益 (Equity) 和 收益率 (ROI)。
*   **杠杆调节**：支持自定义杠杆倍数。
*   **持仓管理**：实时查看当前持仓状态、均价及未实现盈亏。

### 3. AI 智能复盘 (AI Smart Review) 🤖
*   **LLM 集成**：内置 LangChain 支持，可连接大语言模型（如 OpenAI、Claude 等）。
*   **交易分析**：AI 根据您的交易记录自动生成分析报告，指出交易中的优缺点。
*   **个性化配置**：支持管理不同的 LLM 模型配置和 Prompt 模板。

### 4. 技术指标 (Technical Indicators)
*   **主图指标**：
    - 移动平均线 (MA)
    - 指数移动平均线 (EMA)
    - 布林带 (BOLL)
    - **缠论 (CZSC)** 🆕：笔、中枢识别与可视化
*   **副图指标**：
    - 成交量 (Volume)
    - MACD
    - KDJ
    - RSI
    - WR
    - **ADX (平均趋向指数)** 🆕：趋势强度分析
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

## 🎯 新增功能 (2026-02-17)

### 缠论（CZSC）技术分析 🆕
*   **笔识别**：自动识别K线中的"笔"（金色线条）
*   **中枢识别**：自动识别并标记"中枢"区域（青色矩形框）
*   **可视化展示**：在主图上直观显示缠论结构
*   **性能优化**：智能限制分析数据量，确保流畅体验
*   **详细文档**：查看 [CZSC_INTEGRATION.md](./CZSC_INTEGRATION.md)

### ADX 趋势强度指标 🆕
*   **三线显示**：ADX（蓝色）、+DI（绿色）、-DI（红色）
*   **趋势确认**：ADX > 25 表示强趋势，< 20 表示震荡
*   **方向判断**：+DI 与 -DI 的交叉提供交易信号
*   **威尔德平滑**：使用标准威尔德平滑算法计算
*   **详细文档**：查看 [ADX_INDICATOR.md](./ADX_INDICATOR.md)

### 图表交互增强 🆕
*   **鼠标滚轮缩放**：向上滚动放大K线，向下滚动缩小，查看不同细节
*   **缩放中心保持**：缩放时保持视图中心位置，避免内容跳动
*   **缩放范围**：0.5x - 3.0x，支持触摸板和触摸屏
*   **拖动查看**：左右拖动浏览历史数据
*   **详细文档**：查看 [MOUSE_WHEEL_ZOOM.md](./MOUSE_WHEEL_ZOOM.md)

### K线推进模式 🆕
*   **按周期推进**：每次跳跃到下一根完整周期K线，快速浏览
*   **按源K线推进**：每次前进一根源K线，观察K线形成过程
*   **智能速度控制**：源K线模式支持速度调节，周期模式速度固定
*   **统一操作**：播放和观望按钮都遵循推进模式设置
*   **详细文档**：查看 [ADVANCE_MODE_FEATURE.md](./ADVANCE_MODE_FEATURE.md)

### 随机训练模式 🆕
*   **一键开始**：点击即刻开始训练，无需繁琐配置
*   **随机品种**：自动从期货合约中随机选择
*   **智能时间**：在数据的10%-70%范围随机选择，确保训练质量
*   **快速配置**：仅需选择显示模式和止盈止损
*   **详细文档**：查看 [RANDOM_FUTURES_REPLAY.md](./RANDOM_FUTURES_REPLAY.md)

## 🛠 技术栈

*   **框架**: [Flutter](https://flutter.dev/) (UI 构建)
*   **语言**: [Dart](https://dart.dev/)
*   **状态管理**: [Provider](https://pub.dev/packages/provider)
*   **本地数据库**: [Isar](https://isar.dev/) (高性能 NoSQL 数据库)
*   **AI 框架**: [LangChain](https://pub.dev/packages/langchain) (大模型集成)
*   **缠论引擎**: [czsc_dart](./czsc_dart/) (缠中说禅技术分析)
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

## 💡 使用技巧

### 缠论分析技巧
1.  切换到 CZSC 主图指标
2.  观察金色的"笔"线，判断趋势结构
3.  关注青色的"中枢"区域，识别震荡和突破
4.  结合K线形态，提高交易准确率

### ADX 趋势判断技巧
1.  切换到 ADX 副图指标
2.  ADX > 25 时考虑趋势跟随策略
3.  +DI 上穿 -DI 且 ADX 上升：买入信号
4.  -DI 上穿 +DI 且 ADX 上升：卖出信号
5.  ADX < 20 时避免趋势策略，考虑区间操作

### 高效训练技巧
1.  使用**随机训练模式**进行大量训练
2.  设置**按周期推进**快速浏览行情
3.  发现机会后暂停，切换到**按源K线推进**精细分析
4.  使用**滚轮缩放**查看不同时间维度的价格结构

## 📂 项目结构

```
futures_replay/
├── lib/
│   ├── engine/          # 回放与交易核心逻辑引擎
│   ├── models/          # 数据模型 (K线, 交易记录, AI配置等)
│   ├── services/        # 核心服务 (数据库, 账户服务, AI服务, 指标计算)
│   ├── ui/
│   │   ├── chart/       # 自定义图表绘制 (Painter)
│   │   ├── screens/     # 应用页面 (主界面, 设置, 历史记录, AI配置等)
│   │   ├── theme/       # 主题样式与颜色定义
│   │   └── widgets/     # 通用 UI 组件
│   └── main.dart        # 程序入口
├── czsc_dart/           # 缠论分析库（本地依赖）
│   ├── lib/             # 缠论核心算法实现
│   └── test/            # 缠论测试用例
├── test/                # 测试文件
└── docs/                # 文档（功能说明、Bug修复记录等）
```

## 📝 使用指南

1.  **数据准备**：启动应用，进入“导入数据”页面，选择您的 CSV 历史数据文件导入。
2.  **初始化设置**：选择初始资金、杠杆倍数、回放起始时间及 K 线周期。
3.  **开始回放**：点击播放按钮开始回放行情。使用控制面板调整速度或暂停。
4.  **模拟交易**：根据行情判断，点击“买入/做多”或“卖出/做空”。
5.  **复盘分析**：交易结束后，进入“交易历史”查看详细记录，或使用“AI 复盘”获取智能建议。

## 📚 技术文档

### 功能文档
*   [CZSC_INTEGRATION.md](./CZSC_INTEGRATION.md) - 缠论指标集成说明
*   [ADX_INDICATOR.md](./ADX_INDICATOR.md) - ADX指标使用指南
*   [MOUSE_WHEEL_ZOOM.md](./MOUSE_WHEEL_ZOOM.md) - 鼠标滚轮缩放功能
*   [ADVANCE_MODE_FEATURE.md](./ADVANCE_MODE_FEATURE.md) - K线推进模式说明
*   [RANDOM_FUTURES_REPLAY.md](./RANDOM_FUTURES_REPLAY.md) - 随机训练功能

### Bug修复记录
*   [CZSC_BUGFIX.md](./CZSC_BUGFIX.md) - CZSC编译错误修复
*   [CZSC_PERFORMANCE.md](./CZSC_PERFORMANCE.md) - CZSC性能优化
*   [PERIOD_SWITCH_BUGFIX.md](./PERIOD_SWITCH_BUGFIX.md) - 周期切换Bug修复
*   [ADVANCE_MODE_BUGFIX.md](./ADVANCE_MODE_BUGFIX.md) - 推进模式Bug修复

## 🎨 特色亮点

### 缠论（CZSC）技术分析
基于缠中说禅理论，自动识别K线中的笔和中枢结构：
*   **笔**：金色线条连接分型高低点，展示价格走势的骨架
*   **中枢**：青色矩形框标识价格震荡区间
*   **实时更新**：回放过程中动态更新缠论结构
*   **性能优化**：智能限制分析数据量（最多1000根K线）

### ADX 趋势强度分析
使用威尔德平滑算法计算平均趋向指数：
*   **ADX**：衡量趋势强度（0-100），>25表示强趋势
*   **+DI/-DI**：判断趋势方向，交叉产生交易信号
*   **标准算法**：完全遵循 J. Welles Wilder Jr. 的原始算法

### 智能随机训练
*   **零配置启动**：点击"随机训练"立即开始，无需选择品种和时间
*   **智能选择**：在数据的10%-70%范围随机选择起始点
*   **训练泛化**：避免过度拟合单一品种和时段
*   **快速迭代**：适合大量训练，提高交易技能

### 专业图表体验
*   **滚轮缩放**：像 TradingView、同花顺一样的丝滑缩放体验
*   **双推进模式**：适应不同的学习场景（快速浏览 vs 精细学习）
*   **高性能渲染**：CustomPaint + 智能裁剪，即使几千根K线也流畅
