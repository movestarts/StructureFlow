# Futures Replay (K线训练营) - 产品文档

## 1. 项目简介 (Introduction)

**Futures Replay** (K线训练营) 是一款专为交易员和期货投资者设计的专业级历史行情回放与模拟交易训练软件。该软件基于 Flush (Flutter) 开发，支持跨平台运行（当前主要针对 Windows 桌面端优化），旨在帮助用户通过高保真的历史行情复盘，验证交易策略，提升盘感与交易技能。

本项目核心理念是“像真实交易一样复盘”，提供精确到 Tick 级别的 K 线生成（Ghost Bar 机制），支持多周期切换、模拟下单、持仓管理及详细的交易历史分析。

---

## 2. 核心功能 (Core Features)

### 2.1 行情回放系统 (Market Replay)
- **精准回放**: 基于 1 分钟或更精细的源数据，合成任意周期的 K 线（如 5 分钟、15 分钟、1 小时等）。
- **Ghost Bar 机制**: 模拟真实行情的 K 线动态生成过程（高开低收的实时跳动），而非简单的 K 线逐根出现，还原真实的盘面压力。
- **播放控制**: 支持 播放/暂停、倍速调整（从 0.1x 到 10x）、单步前进（Next Bar）、以及回退（Undo）功能。
- **多周期支持**: 用户可在复盘过程中切换不同的时间周期视图，系统自动重新聚合 K 线数据。

### 2.2 模拟交易系统 (Trading Simulation)
- **全功能下单**: 支持 开多 (Long)、开空 (Short)、平仓 (Close) 操作。
- **资金管理**:
  - 实时计算浮动盈亏 (Floating PnL)。
  - 账户权益 (Equity) 与 余额 (Balance) 动态更新。
  - 支持杠杆设置与保证金计算。
- **仓位计算器**: 内置仓位计算工具，辅助用户根据风险偏好计算合理的开仓数量。

### 2.3 数据管理 (Data Management)
- **数据导入**: 支持标准 CSV 格式的历史 K 线数据导入。
- **本地数据库**: 集成 **Isar Database** 高性能数据库，对导入的数据进行本地化存储与索引，大幅提升数据加载与查询速度（相比直接读取 CSV 文件）。
- **数据维护**: 提供数据清理与管理界面，用户可按需删除过期的历史数据。

### 2.4 分析与复盘 (Analysis & Review)
- **交易历史**: 详细记录每一笔交易的开仓点、平仓点、盈亏额及收益率。
- **图表复盘**: 在 K 线图上直观标记买卖点，支持复盘查看每一局的完整交易路径。
- **统计报表**: 提供胜率、盈亏比、最大回撤等关键交易指标的统计分析（部分功能规划中）。
- **技术指标**: 支持常用的技术指标（如 MA, BOLL, MACD, RSI 等）叠加显示。

### 2.5 个性化设置 (Customization)
- **主题切换**: 支持 深色 (Dark Mode) 与 浅色 (Light Mode) 两种专业交易界面主题。
- **快捷键**: 支持常用操作（如 开仓、平仓、暂停、下一根 K 线）的快捷键自定义，提升训练效率。
- **布局调整**: 可自定义图表与面板的布局方式。

---

## 3. 技术架构 (Technical Architecture)

本项目采用清晰的分层架构，确保代码的可维护性与扩展性：

### 3.1 核心技术栈
- **Framework**: [Flutter](https://flutter.dev) (UI 构建与跨平台支持)
- **State Management**: [Provider](https://pub.dev/packages/provider) (全局状态管理与依赖注入)
- **Database**: [Isar](https://isar.dev) (高性能本地 NoSQL 数据库，用于存储海量 K 线数据)
- **Charting**: 自研高性能 K 线绘图引擎（基于 `CustomPainter`），优化大量数据下的渲染性能。

### 3.2 模块划分
- **`lib/engine/`**: 核心业务逻辑层。
  - `ReplayEngine`: 负责时间轴管理、K 线聚合、Ghost Bar 生成。
  - `TradeEngine`: 负责订单处理、资金结算、持仓维护。
- **`lib/services/`**: 数据与基础设施层。
  - `DatabaseService`: 封装 Isar 数据库操作，处理数据的增删改查。
  - `DataService`: 处理原始数据（CSV）的解析与预处理。
  - `AccountService`: 管理用户账户资金与交易记录。
  - `SettingsService`: 管理应用配置与持久化。
- **`lib/models/`**: 数据模型层。定义 `KlineModel` (K线), `TradeRecord` (交易记录) 等实体。
- **`lib/ui/`**: 界面展示层。
  - `screens/`: 各个功能页面（主页、设置、复盘页等）。
  - `chart/`: K 线图表组件与交互逻辑。
  - `widgets/`: 通用 UI 组件（按钮、输入框、对话框等）。

---

## 4. 快速开始 (Quick Start)

1. **环境准备**: 确保本地已安装 Flutter SDK (推荐 3.x 版本) 及 Dart 环境。
2. **依赖安装**: 在项目根目录下运行 `flutter pub get`。
3. **运行项目**:
   -连接 Windows 设备或模拟器。
   - 运行 `flutter run -d windows` (推荐在 Windows 桌面端运行以获得最佳体验)。
4. **开始训练**:
   - 启动应用后，点击 "导入数据" (Import Data) 加载 CSV 格式的行情文件。
   - 在主界面选择已导入的品种，点击 "开始复盘" (Start Replay)。
   - 使用控制面板或快捷键进行模拟交易。

---

## 5. 项目结构说明 (File Structure)

```
lib/
├── engine/          # 核心引擎 (Replay, Trade)
├── models/          # 数据模型定义
├── services/        # 后端服务 (Database, Data, Account)
├── ui/              # 用户界面
│   ├── chart/       # 图表绘制相关
│   ├── screens/     # 页面文件
│   └── widgets/     # 通用小部件
├── utils/           # 工具类
└── main.dart        # 程序入口
```

---

*文档生成时间: 2026-02-15*
