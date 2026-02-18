# CZSC (缠中说禅) 指标整合说明

## 整合完成 ✅

已成功将 `czsc_dart` 缠论分析工具整合到 futures_replay 项目中，作为主图的技术指标。

## 功能特性

### 1. 缠论核心算法
- ✅ K线包含关系处理
- ✅ 分型识别（顶分型、底分型）
- ✅ 笔识别与绘制
- ✅ 中枢识别与绘制

### 2. 可视化展示
- **笔（BI）**: 使用金色线条绘制，连接分型高低点
- **中枢（ZS）**: 使用青色半透明矩形框标识，显示中枢区间
  - 上沿（ZG）：前3笔的最小高点
  - 下沿（ZD）：前3笔的最大低点
  - 中轴（ZZ）：虚线表示

### 3. 统计信息
在图表顶部显示：
- 笔的数量
- 中枢的数量

## 使用方法

### 1. 在主界面使用
1. 启动应用，进入交易复盘界面
2. 在图表顶部的指标栏找到 **CZSC** 按钮
3. 点击切换到缠论指标显示
4. 图表将显示：
   - 金色的笔线（连接分型点）
   - 青色的中枢矩形框
   - 中枢中轴虚线

### 2. 在历史交易回看中使用
1. 在交易历史页面选择要回看的交易记录
2. 进入K线回看界面
3. 同样在指标栏点击 **CZSC** 按钮切换显示

## 技术实现

### 1. 依赖添加
```yaml
# pubspec.yaml
dependencies:
  czsc_dart:
    path: ./czsc_dart
  collection: ^1.18.0
```

### 2. 核心文件修改

#### a. `lib/services/indicator_service.dart`
添加了 `calculateCZSC()` 方法，将 K线数据转换为 czsc_dart 的数据格式并进行分析。

```dart
CZSCResult calculateCZSC(List<KlineModel> data, String symbol) {
  // 转换数据格式
  // 创建 CZSC 分析器
  // 返回笔、中枢、分型数据
}
```

#### b. `lib/ui/chart/kline_painter.dart`
扩展了 `MainIndicatorType` 枚举，添加了 `czsc` 选项，并实现了绘制逻辑：

- `_drawBiList()`: 绘制笔
- `_drawZsList()`: 绘制中枢
- `_drawIndicatorLabels()`: 显示统计信息

#### c. `lib/ui/screens/main_screen.dart` 和 `trade_history_chart_screen.dart`
- 添加 CZSC 数据缓存变量
- 在 `_updateIndicators()` 中计算 CZSC 数据
- 在指标切换栏添加 CZSC 按钮
- 向 KlinePainter 传递 CZSC 数据

### 3. 数据流程

```
KlineModel 数据
    ↓
转换为 RawBar (czsc_dart格式)
    ↓
CZSC 分析器处理
    ↓
生成 BI (笔) 和 ZS (中枢)
    ↓
KlinePainter 绘制到画布
```

## 配置选项

可以通过 `CzscConfig` 调整参数：

```dart
// 在 czsc_dart/lib/src/analyze.dart 中
CzscConfig.minBiLen = 4;      // 最小笔长度（默认4根K线）
CzscConfig.maxBiNum = 100;     // 最大保留笔数量（默认100）
CzscConfig.verbose = false;    // 是否输出详细日志
```

## 颜色说明

- **笔（BI）**: 金色 (#FFD700)
- **中枢（ZS）**: 青色 (#00CED1)
  - 填充: 20% 透明度
  - 边框: 实线
  - 中轴: 虚线，50% 透明度
- **分型端点**: 
  - 向上笔: 红色圆点（看涨）
  - 向下笔: 绿色圆点（看跌）

## 注意事项

1. **数据量要求**: CZSC 分析需要足够的K线数据（建议至少50根）才能识别出有效的笔和中枢
2. **性能考虑**: 对于大量K线数据，CZSC 计算可能需要一定时间，已做了异常处理以确保不影响主界面
3. **周期适配**: 默认使用 5分钟周期（Freq.f5），可根据实际数据调整
4. **有效性判断**: 只显示有效的中枢（笔数≥3 且 zg ≥ zd）

## 调试建议

如果 CZSC 指标显示异常：

1. 检查K线数据量是否充足
2. 查看控制台是否有异常日志
3. 确认 czsc_dart 依赖已正确安装（运行 `flutter pub get`）
4. 尝试调整 `CzscConfig.minBiLen` 参数

## 未来优化方向

- [ ] 添加分型标记的显示选项
- [ ] 支持不同级别的笔（5分钟笔、30分钟笔等）
- [ ] 添加中枢扩展和破坏的视觉提示
- [ ] 性能优化：增量更新而非每次重新计算全部数据
- [ ] 添加用户可配置的参数界面

## 参考资料

- [czsc_dart 源码](./czsc_dart/)
- [缠论基础知识](https://github.com/waditu/czsc)
- 缠中说禅博客文章

---

整合完成时间: 2026-02-17
整合人员: AI Assistant
