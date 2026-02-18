# 随机合约复盘功能

## 🎯 功能说明

为"合约训练 - 复盘模式"实现了随机复盘功能，一键开始训练，无需繁琐配置。

## ✨ 核心特性

### 1. 随机选择合约
- 自动从缓存目录扫描所有期货合约CSV文件
- 随机选择一个合约品种
- 用户无需手动选择，减少操作步骤

### 2. 智能随机时间
- 随机选择起始时间，但**不会太靠后**
- 选择范围：数据的 10% ~ 70% 位置
- 确保有足够的K线数据用于复盘训练
- 避免数据初期不稳定的区域

### 3. 简洁配置对话框
类似图二的简单界面，只需配置：
- **显示模式**：竖屏 / 横屏
- **止盈止损**：启用 / 关闭

## 🎮 使用流程

### 用户体验

1. **点击"复盘模式"** 
   ↓
2. **自动随机选择合约和时间**（加载提示：正在加载 RB...）
   ↓
3. **弹出简单配置对话框**
   - 选择显示模式（竖屏/横屏）
   - 选择是否启用止盈止损
   ↓
4. **点击"确认"**
   ↓
5. **立即开始训练**

### 操作步骤
1. 在主页点击"合约训练 (多空杠杆)"卡片
2. 点击"复盘模式"按钮
3. 等待1-2秒加载数据
4. 在对话框中选择显示模式和止盈止损
5. 点击"确认"开始训练

**优势**：
- ✅ 只需2次点击即可开始
- ✅ 无需选择品种和时间
- ✅ 真正的"随机"训练体验

## 📐 技术实现

### 1. 随机选择合约

```dart
Future<void> _startRandomFuturesReplay() async {
  // 1. 扫描期货合约文件
  final futuresDir = Directory('.../cryptotrainer/csv/futures');
  final futuresFiles = futuresDir.listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.csv'))
    .toList();

  // 2. 随机选择
  final random = Random();
  final selectedFile = futuresFiles[random.nextInt(futuresFiles.length)];
  
  // 3. 提取品种代码
  final instrumentCode = filename
    .replaceAll('.csv', '')
    .replaceAll(RegExp(r'[_\-\d]'), '')
    .toUpperCase();
  
  // ...
}
```

### 2. 智能随机时间

```dart
// 在数据的 10%-70% 范围内随机选择
final maxStartIndex = (allData.length * 0.7).floor();
final minStartIndex = (allData.length * 0.1).floor();
final randomStartIndex = minStartIndex + random.nextInt(maxStartIndex - minStartIndex);
```

**为什么是10%-70%？**

- **跳过前10%**：避免数据初期可能的异常或不稳定
- **不超过70%**：确保至少有30%的数据用于复盘
- **假设默认200根K线**：至少留出 `allData.length * 0.3` 的空间

**示例**：
- 数据总量：5000根K线
- 选择范围：500 ~ 3500 索引
- 剩余空间：至少1500根K线（足够复盘）

### 3. 快速配置对话框

```dart
void _showQuickConfigDialog(...) {
  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        child: Column(
          children: [
            // 标题
            Text('止盈止损设置'),
            
            // 显示模式：竖屏/横屏
            Row([
              _buildQuickModeOption('竖屏', 0, ...),
              _buildQuickModeOption('横屏', 1, ...),
            ]),
            
            // 启用止盈止损
            Checkbox(...),
            
            // 按钮：取消/确认
            Row([
              OutlinedButton('取消'),
              ElevatedButton('确认'),
            ]),
          ],
        ),
      );
    },
  );
}
```

### 4. 启动训练

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => Theme(
      data: AppTheme.darkTheme,
      child: MainScreen(
        allData: allData,
        startIndex: randomStartIndex,
        limit: 200,  // 默认200根K线
        instrumentCode: instrumentCode,
        initialPeriod: Period.m5,  // 默认5分钟周期
        spotOnly: false,
        csvPath: csvPath,
      ),
    ),
  ),
);
```

## 🎨 对话框UI设计

### 布局结构

```
┌─────────────────────────┐
│     止盈止损设置         │
├─────────────────────────┤
│ 显示模式                │
│ ┌──────┐  ┌──────┐     │
│ │ ⦿竖屏│  │ ○横屏│     │
│ └──────┘  └──────┘     │
│                         │
│ ┌─────────────────────┐│
│ │启用止盈止损      □  ││
│ └─────────────────────┘│
│                         │
│ ┌────┐  ┌──────────┐  │
│ │取消│  │   确认    │  │
│ └────┘  └──────────┘  │
└─────────────────────────┘
```

### 视觉效果

- **单选按钮**：选中时显示蓝色边框和背景色
- **复选框**：Material Design风格
- **按钮**：取消（outline）+ 确认（filled）
- **圆角**：统一使用12-20px圆角

## 📊 参数说明

### 固定参数
- **默认周期**：5分钟（Period.m5）
- **训练数量**：200根K线
- **选择范围**：数据的10%-70%

### 可配置参数
- **显示模式**：竖屏(0) / 横屏(1)
- **止盈止损**：启用(true) / 关闭(false)

### 调整建议

如果需要修改随机范围：

```dart
// 更保守（留更多空间）
final maxStartIndex = (allData.length * 0.6).floor();  // 改为60%
final minStartIndex = (allData.length * 0.2).floor();  // 改为20%

// 更激进（可以选择更靠后的位置）
final maxStartIndex = (allData.length * 0.8).floor();  // 改为80%
final minStartIndex = (allData.length * 0.05).floor(); // 改为5%
```

## 🔄 与原有模式的区别

| 特性 | 原配置模式 | 随机复盘模式 ✨ |
|-----|-----------|----------------|
| 选择品种 | ✅ 用户选择 | ⚡ 随机选择 |
| 选择时间 | ✅ 用户选择 | ⚡ 随机选择 |
| 选择周期 | ✅ 用户选择 | ⚡ 固定5分钟 |
| 训练数量 | ✅ 用户输入 | ⚡ 固定200根 |
| 显示模式 | ✅ 用户选择 | ✅ 用户选择 |
| 止盈止损 | ✅ 用户选择 | ✅ 用户选择 |
| 操作步骤 | 6-7步 | **2步** |
| 启动速度 | 慢 | **快** |

## 🎲 伪随机说明

### 随机性保证

使用 Dart 的 `Random()` 类：

```dart
final random = Random();

// 随机品种
final selectedFile = futuresFiles[random.nextInt(futuresFiles.length)];

// 随机时间
final randomStartIndex = minStartIndex + random.nextInt(maxStartIndex - minStartIndex);
```

### 为什么是"伪随机"？

1. **不是真正的完全随机**
   - 限制在10%-70%范围内
   - 确保训练质量

2. **可预测性**
   - 每次随机但在合理范围内
   - 不会出现极端情况

3. **训练友好**
   - 保证有足够的数据可以复盘
   - 避免选到数据末尾

## 🛡️ 错误处理

### 场景1: 没有合约数据

```dart
if (futuresFiles.isEmpty) {
  _showError('没有找到期货合约数据\n请先导入CSV文件');
  return;
}
```

### 场景2: 数据加载失败

```dart
if (allData.isEmpty) {
  _showError('数据加载失败或为空');
  return;
}
```

### 场景3: 加载中断

使用 `mounted` 检查：
```dart
if (!mounted) return;
```

## 🔧 目录结构

### 期货合约数据位置

```
Documents/
└── cryptotrainer/
    └── csv/
        └── futures/
            ├── RB.csv      ← 螺纹钢
            ├── AL.csv      ← 铝
            ├── CU.csv      ← 铜
            └── ...
```

### 加载顺序

1. 首先检查：`Documents/cryptotrainer/csv/futures/`
2. 扫描所有 `.csv` 文件
3. 随机选择一个文件加载

## 📱 用户界面流程

### 流程图

```
主页
  ↓ 点击"复盘模式"
自动随机选择品种和时间
  ↓ 显示加载提示
加载合约数据（1-2秒）
  ↓ 关闭加载提示
弹出快速配置对话框
  ├─ 选择显示模式（竖屏/横屏）
  └─ 选择止盈止损（启用/关闭）
  ↓ 点击"确认"
启动训练界面
```

## 🎯 其他训练模式

### 当前实现状态

| 模式 | 实现状态 | 行为 |
|-----|---------|------|
| 合约复盘 | ✅ 随机模式 | 随机品种+时间，快速配置 |
| 合约随机训练 | ⚪ 原配置 | 进入SetupScreen |
| 合约裸K训练 | ⚪ 原配置 | 进入SetupScreen |
| 现货复盘 | ⚪ 原配置 | 进入SetupScreen |
| 现货随机训练 | ⚪ 原配置 | 进入SetupScreen |
| 现货裸K训练 | ⚪ 原配置 | 进入SetupScreen |

### 未来扩展

可以为其他模式也实现类似的随机功能：

```dart
void _onModeSelected(TrainingType type) {
  switch (type) {
    case TrainingType.futuresReplay:
      _startRandomFuturesReplay();  // ✅ 已实现
      break;
    case TrainingType.futuresRandom:
      _startRandomFuturesRandom();  // 可以实现
      break;
    case TrainingType.spotReplay:
      _startRandomSpotReplay();     // 可以实现
      break;
    default:
      Navigator.push(...SetupScreen...);
  }
}
```

## 📁 修改的文件

1. ✅ `lib/ui/screens/home_screen.dart` - 添加随机复盘逻辑

### 新增代码

- `_startRandomFuturesReplay()` - 主函数（~60行）
- `_showQuickConfigDialog()` - 配置对话框（~120行）
- `_buildQuickModeOption()` - 单选按钮组件（~40行）
- `_showError()` - 错误提示（~20行）
- 导入语句（~5行）

### 代码行数
- 新增：~245 行
- 修改：~5 行
- 总计：~250 行

## 🧪 测试场景

### 测试1: 正常流程
1. 确保 `Documents/cryptotrainer/csv/futures/` 目录有CSV文件
2. 点击"合约训练 - 复盘模式"
3. ✅ 应该显示加载提示（品种名）
4. ✅ 应该弹出配置对话框
5. 选择配置后点击"确认"
6. ✅ 应该进入训练界面

### 测试2: 无数据情况
1. 确保没有期货合约数据
2. 点击"合约训练 - 复盘模式"
3. ✅ 应该显示错误提示："没有找到期货合约数据"

### 测试3: 多次随机
1. 多次点击"复盘模式"
2. ✅ 每次应该选择不同的品种（概率性）
3. ✅ 每次应该选择不同的起始时间

### 测试4: 配置选项
1. 进入配置对话框
2. 切换显示模式
3. 切换止盈止损
4. ✅ 选项应该正确高亮
5. ✅ 点击"确认"应该使用选择的配置

## 💡 设计思路

### 为什么要随机？

1. **避免过度拟合**
   - 不是每次都在同一个品种、同一个时间段训练
   - 提高训练的泛化能力

2. **减少选择疲劳**
   - 用户不需要每次都纠结选哪个品种
   - 快速进入训练状态

3. **更接近实战**
   - 实战中无法选择市场
   - 训练随机品种提高适应能力

### 为什么不要太靠后？

假设数据有5000根K线，默认训练200根：

| 起始位置 | 剩余数据 | 问题 |
|---------|---------|------|
| 0% (0) | 5000根 | ✅ 充足 |
| 50% (2500) | 2500根 | ✅ 充足 |
| 70% (3500) | 1500根 | ✅ 足够 |
| 90% (4500) | 500根 | ⚠️ 偏少 |
| 96% (4800) | 200根 | ❌ 刚好，无余量 |

**结论**：限制在70%可以确保：
- 至少有30%的数据可用
- 足够进行有意义的复盘
- 有余量应对意外情况

## 🎁 额外功能

### 加载提示

显示友好的加载提示，包含品种名称：

```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => Center(
    child: Container(
      child: Column(
        children: [
          CircularProgressIndicator(),
          Text('正在加载 $instrumentCode...'),
        ],
      ),
    ),
  ),
);
```

### 错误提示

统一的错误提示对话框：

```dart
void _showError(String message) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('提示'),
      content: Text(message),
      actions: [
        TextButton('确定'),
      ],
    ),
  );
}
```

## 🔮 未来优化方向

### 1. 可配置的随机范围
```dart
// 在设置中添加
int randomRangeStart = 10;  // 10%
int randomRangeEnd = 70;    // 70%
```

### 2. 智能品种过滤
```dart
// 只随机活跃的品种
final activeFutures = ['RB', 'AL', 'CU', 'ZN'];
final filtered = futuresFiles.where((f) => 
  activeFutures.any((code) => f.path.contains(code))
).toList();
```

### 3. 历史避免重复
```dart
// 记录最近训练的品种和时间
List<String> recentSessions = [];

// 避免连续两次相同
while (recentSessions.contains(selectedKey)) {
  selectedFile = futuresFiles[random.nextInt(futuresFiles.length)];
}
```

### 4. 难度选择
```dart
// 简单：留更多数据
// 中等：当前实现
// 困难：更少的数据（80%-95%）
```

---

**实现时间**: 2026-02-17  
**功能类型**: 快速训练模式  
**状态**: ✅ 完成并测试通过  
**版本**: 1.0.0
