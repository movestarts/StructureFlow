# K线推进模式设置功能

## 📌 功能说明

为复盘页面添加了K线推进模式选择功能，用户可以在两种模式之间切换。

## 🎯 两种推进模式

### 1. 使用源K线推进（默认关闭）

**特点**：
- 按照原始数据源的频率推进（如1分钟、5分钟）
- 每次播放前进一根源K线
- 可以看到K线逐根形成的过程
- 支持速度调节（50ms - 2000ms）

**适用场景**：
- 想要观察K线形成的细节
- 学习K线形态
- 精细分析盘口变化

**示例**：
- 源数据是1分钟K线，显示周期是5分钟
- 每次播放前进1根1分钟K线
- 5分钟K线会逐渐"生长"

### 2. 按照周期推进（默认开启）✅

**特点**：
- 按照当前显示周期推进（如5分钟、30分钟）
- 每次播放前进一根完整的周期K线
- 快速浏览行情走势
- 速度固定，不可调节

**适用场景**：
- 快速回顾历史走势
- 观察周期级别的价格变化
- 快速定位关键位置

**示例**：
- 显示周期是30分钟
- 每次播放跳到下一根30分钟K线
- 速度快，适合快速浏览

## 🛠️ 使用方法

### 打开设置

在复盘页面有两个入口可以打开设置：

1. **顶部工具栏** - 点击设置图标（⚙️）
2. **副图指标栏** - 点击调节图标（🎚️）

### 切换推进模式

1. 点击设置图标打开"K线图表设置"对话框
2. 看到两个单选按钮：
   - ○ 使用源K线推进
   - ⦿ 按照周期推进（默认选中）
3. 点击选择你想要的模式
4. 设置立即生效

### 调节播放速度

**仅在"使用源K线推进"模式下可用**

1. 选择"使用源K线推进"模式
2. 速度滑块和快捷按钮会激活
3. 使用滑块或点击快捷按钮调节速度：
   - **5x** (100ms) - 最快
   - **2x** (250ms) - 较快
   - **1x** (500ms) - 正常
   - **0.5x** (1000ms) - 较慢
   - 或拖动滑块自定义（50ms - 2000ms）

### 视觉反馈

- **按周期推进时**：速度控制会变灰，提示不可用
- **按源K线推进时**：速度控制恢复正常颜色，可以调节

## 📐 技术实现

### 1. ReplayEngine 扩展

**文件**: `lib/engine/replay_engine.dart`

添加了推进模式支持：

```dart
class ReplayEngine extends ChangeNotifier {
  // 推进模式：true=按周期推进，false=按源K线推进
  bool _advanceByPeriod = true;
  
  bool get advanceByPeriod => _advanceByPeriod;
  
  void setAdvanceMode(bool byPeriod) {
    _advanceByPeriod = byPeriod;
    notifyListeners();
  }
  
  void _startTimer() {
    _timer = Timer.periodic(_tickDuration, (_) {
      if (_advanceByPeriod) {
        nextBar();  // 按周期推进
      } else {
        next();     // 按源K线推进
      }
    });
  }
}
```

### 2. UI 对话框

**文件**: `lib/ui/screens/main_screen.dart`

#### a. 添加状态变量

```dart
// K线推进模式：true=按周期推进，false=按源K线推进
bool _advanceByPeriod = true;
```

#### b. 修改设置对话框

```dart
void _showSpeedDialog() {
  // 添加推进模式选择
  RadioListTile<bool>(
    title: const Text('使用源K线推进'),
    value: false,
    groupValue: currentAdvanceByPeriod,
    onChanged: (value) {
      setState(() => _advanceByPeriod = value);
      _replayEngine.setAdvanceMode(value);
    },
  ),
  RadioListTile<bool>(
    title: const Text('按照周期推进'),
    value: true,
    groupValue: currentAdvanceByPeriod,
    onChanged: (value) {
      setState(() => _advanceByPeriod = value);
      _replayEngine.setAdvanceMode(value);
    },
  ),
  
  // 速度滑块（按周期推进时禁用）
  Slider(
    onChanged: currentAdvanceByPeriod ? null : (v) { ... },
  ),
}
```

#### c. 初始化时设置模式

```dart
@override
void initState() {
  _replayEngine = ReplayEngine(...);
  _replayEngine.setAdvanceMode(_advanceByPeriod); // 设置初始模式
  // ...
}
```

#### d. 切换周期时保持模式

```dart
void _switchPeriod(Period p) {
  _replayEngine = ReplayEngine(...);
  _replayEngine.setAdvanceMode(_advanceByPeriod); // 保持设置
  // ...
}
```

## 🎮 行为说明

### 按周期推进模式

```
源数据: 1m K线
显示周期: 5m
播放行为: 
  09:00 → 09:05 → 09:10 → 09:15 ...
  (每次跳一根5分钟K线)
```

### 按源K线推进模式

```
源数据: 1m K线
显示周期: 5m
播放行为:
  09:00 → 09:01 → 09:02 → 09:03 → 09:04 → 09:05 ...
  (每次前进一根1分钟K线，5分钟K线逐渐"生长")
```

## 📊 对比

| 特性 | 按周期推进 | 按源K线推进 |
|------|-----------|------------|
| 速度 | 快 | 可调节（50-2000ms） |
| 播放方式 | 跳跃式 | 连续式 |
| K线形成 | 直接显示完整K线 | 逐根形成 |
| 适用场景 | 快速浏览 | 精细学习 |
| 速度控制 | ❌ 不支持 | ✅ 支持 |
| 默认模式 | ✅ 是 | ❌ 否 |

## 💡 使用建议

### 场景1: 快速定位

1. 选择"按照周期推进"
2. 快速播放找到目标区域
3. 暂停后切换到"使用源K线推进"
4. 慢速播放查看细节

### 场景2: 学习K线形态

1. 选择"使用源K线推进"
2. 设置较慢的速度（1000ms）
3. 观察K线如何逐根形成
4. 学习形态识别

### 场景3: 回顾交易

1. 按照周期推进快速到达交易时间点
2. 暂停
3. 手动前进/后退查看详情

## 🎨 UI 设计

### 对话框布局

```
┌─────────────────────────┐
│   K线图表设置           │
├─────────────────────────┤
│ 推进模式                │
│ ○ 使用源K线推进          │
│ ⦿ 按照周期推进           │
├─────────────────────────┤
│ 自动模式速度            │
│ (使用源k线推进生效)      │
│ ════════●════════       │
│ 快    500ms/tick   慢   │
│ [5x] [2x] [1x] [0.5x]  │
└─────────────────────────┘
```

### 交互状态

**按周期推进时**：
- ✅ 单选按钮高亮
- ⚪ 速度滑块变灰禁用
- ⚪ 速度文字变灰
- ⚪ 快捷按钮半透明不可点击

**按源K线推进时**：
- ✅ 单选按钮高亮
- ✅ 速度滑块可用
- ✅ 速度文字正常
- ✅ 快捷按钮可点击

## 🔧 技术细节

### 播放逻辑

```dart
void _startTimer() {
  _timer = Timer.periodic(_tickDuration, (_) {
    if (_advanceByPeriod) {
      nextBar();  // 跳到下一根完整周期K线
    } else {
      next();     // 前进一根源K线
    }
  });
}
```

### 手动推进

用户按下方向键时：
- 如果是"按周期推进"：调用 `nextBar()`
- 如果是"按源K线推进"：调用 `next()`

（当前实现：手动推进始终是 `next()`，可以根据需要调整）

## 📁 修改的文件

1. ✅ `lib/engine/replay_engine.dart` - 添加推进模式支持
2. ✅ `lib/ui/screens/main_screen.dart` - UI和逻辑集成

## 🧪 测试场景

### 测试1: 模式切换
1. 打开设置
2. 切换推进模式
3. ✅ 播放行为应该改变
4. ✅ 速度控制应该正确启用/禁用

### 测试2: 按周期推进
1. 选择"按照周期推进"
2. 选择30分钟周期
3. 点击播放
4. ✅ 应该每次跳一根30分钟K线

### 测试3: 按源K线推进
1. 选择"使用源K线推进"
2. 调节速度为500ms
3. 选择30分钟周期显示
4. 点击播放
5. ✅ 应该看到30分钟K线逐渐形成

### 测试4: 切换周期
1. 设置推进模式
2. 切换到不同周期
3. ✅ 推进模式设置应该保留

## 🎁 额外改进

### 视觉优化
- ✅ 禁用状态时控件变灰
- ✅ 添加提示文字"(使用源k线推进生效)"
- ✅ 快捷按钮半透明效果

### 用户体验
- ✅ 设置即时生效，无需确认
- ✅ 状态在对话框关闭后保持
- ✅ 切换周期后保留设置

## 📝 代码变更

### 新增代码
- 推进模式状态变量
- 单选按钮UI
- 条件禁用逻辑
- 模式切换处理

### 代码行数
- 新增：~60 行
- 修改：~20 行
- 总计：~80 行

---

**实现时间**: 2026-02-17  
**状态**: ✅ 功能完成  
**版本**: 1.0.0
