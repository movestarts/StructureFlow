# 期货数据转换工具 - 使用说明

## 🚀 立即使用

### 方法1：双击运行（最简单）

直接双击文件：
```
csv_converter_gui.pyw
```

或在命令行运行：
```bash
cd d:\code\trend\futures_replay\scripts
python csv_converter_gui.pyw
```

### 方法2：如果双击无效，用这个命令

```bash
cd d:\code\trend\futures_replay\scripts  
python csv_converter_gui.pyw
```

## ✨ 功能

- ✅ 支持单个/批量文件转换
- ✅ 自动识别多种格式（天勤SDK、通达信、AkShare等）
- ✅ 自动命名输出文件
- ✅ 实时日志显示
- ✅ 支持多种合约（RB、M、AU、AG等）

## 📋 使用步骤

1. 运行程序（双击 `csv_converter_gui.pyw`）
2. 点击"选择单个文件"或"选择多个文件"
3. 选择需要转换的CSV文件
4. 自动转换并保存到原文件目录
5. 查看日志确认转换结果

## 📊 支持的输入格式

### 格式1：天勤SDK
```csv
datetime,open,high,low,close,volume,open_oi,close_oi
2025-01-02 09:00:00,3320,3325,3318,3322,50000,100000,100500
```

### 格式2：通达信
```csv
时间,开盘价,最高价,最低价,收盘价,成交量
2025-01-02 09:00:00,3320,3325,3318,3322,50000
```

### 格式3：AkShare
```csv
datetime,open,high,low,close,volume
2025-01-02 09:00:00,3320,3325,3318,3322,50000
```

## 📤 输出格式

统一输出为：
```csv
datetime,open,high,low,close,volume
2025-01-02 09:00:00,3320,3325,3318,3322,50000
```

## 🏷️ 自动命名规则

| 输入文件名包含 | 输出文件名 | 合约说明 |
|-------------|-----------|---------|
| rb | RB2505.csv | 螺纹钢主连 |
| m | M2505.csv | 豆粕主连 |
| au | AU2506.csv | 黄金主连 |
| ag | AG2506.csv | 白银主连 |
| 其他 | converted_原文件名.csv | 通用命名 |

## ⚠️ 注意事项

1. **必须安装pandas**
   ```bash
   pip install pandas
   ```

2. **CSV文件编码**
   - 支持UTF-8和GBK编码
   - 如遇乱码，请先转为UTF-8

3. **数据过滤**
   - 自动过滤 `close <= 0` 的无效数据

## 📦 打包为EXE（可选）

如需打包为exe文件（分发给他人），优化版打包正在后台进行中。

或手动打包：
```bash
cd d:\code\trend\futures_replay\scripts
.\build_optimized.bat
```

完成后在 `dist` 目录找到 `期货数据转换工具.exe`

## 🔧 常见问题

### Q: 提示找不到pandas？
A: 运行 `pip install pandas`

### Q: 双击pyw文件没反应？
A: 用命令行运行：`python csv_converter_gui.pyw`

### Q: 转换后的文件能直接用吗？
A: 是的，可直接在Flutter应用中导入使用

### Q: 支持哪些合约？
A: 当前支持RB、M、AU、AG，其他合约会用通用命名

## 📁 相关文件

- `csv_converter_gui.pyw` - GUI程序（主文件）
- `batch_convert_csv.py` - 批处理脚本（命令行版本）
- `build_optimized.bat` - 优化打包脚本
- `快速使用指南.txt` - 快速参考
- `使用说明.md` - 完整文档

## 🎯 快速测试

1. 准备一个CSV文件（任意格式）
2. 双击 `csv_converter_gui.pyw`
3. 选择文件
4. 查看原目录生成的转换文件

## 💡 提示

- 程序使用Tkinter GUI，无需额外安装GUI库
- .pyw扩展名在Windows下运行不会显示命令行窗口
- 支持批量选择多个文件同时转换
- 转换过程在后台线程进行，不会卡住界面

## 📞 技术支持

如有问题，请查看日志输出或联系开发团队。

---

**版本**: v1.0  
**更新时间**: 2026-02-17  
**作者**: Futures Replay Team
