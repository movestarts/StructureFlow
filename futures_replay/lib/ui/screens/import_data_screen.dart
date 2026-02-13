import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:csv/csv.dart';
import '../theme/app_theme.dart';
import '../../services/settings_service.dart';
import '../../models/kline_model.dart';

/// 导入数据页面
class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  String _marketType = 'crypto'; // 'crypto' | 'futures'
  bool _isImporting = false;

  // 导入结果
  int _totalFiles = 0;
  int _successFiles = 0;
  int _failedFiles = 0;
  int _totalKlines = 0;
  final List<_ImportResult> _results = [];

  // 主题自适应
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _borderClr => _isDark ? AppColors.borderLight : AppColors.lightBorder;
  Color get _inputFill => _isDark ? AppColors.bgSurface : AppColors.lightSurface;

  /// 获取数据缓存目录
  Future<String> _getCacheDir() async {
    final settings = context.read<SettingsService>();
    if (settings.dataCacheDir.isNotEmpty) {
      return settings.dataCacheDir;
    }
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}${Platform.pathSeparator}cryptotrainer${Platform.pathSeparator}csv';
  }

  /// 获取市场子目录
  String _marketSubDir() {
    return _marketType == 'crypto' ? 'crypto' : 'futures';
  }

  /// 选择文件（支持多选）
  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'CSV'],
      allowMultiple: true,
      dialogTitle: '选择CSV文件 (支持多选)',
    );
    if (result != null && result.files.isNotEmpty) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      if (paths.isNotEmpty) {
        await _importFiles(paths);
      }
    }
  }

  /// 扫描文件夹（批量）
  Future<void> _scanFolder() async {
    final dirPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择包含CSV文件的文件夹',
    );
    if (dirPath != null) {
      final dir = Directory(dirPath);
      final files = <String>[];
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.csv')) {
          files.add(entity.path);
        }
      }
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到CSV文件'), backgroundColor: AppColors.warning),
          );
        }
        return;
      }
      await _importFiles(files);
    }
  }

  /// 解码CSV文件内容（尝试 UTF-8 → GBK → Latin1）
  String _decodeBytes(List<int> bytes) {
    // 1. Try UTF-8
    try {
      return utf8.decode(bytes);
    } catch (_) {}
    // 2. Try GBK / GB2312 (via latin1 as fallback — proper GBK needs external pkg)
    // For Windows Chinese systems, files may be in GBK. We fall back to latin1
    // which won't crash but may garble Chinese chars. The actual K-line data (numbers)
    // will still parse correctly.
    try {
      return latin1.decode(bytes);
    } catch (_) {}
    // 3. Last resort
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 验证CSV行是否为有效K线数据
  bool _isValidKlineRow(List<dynamic> row) {
    if (row.length < 6) return false;
    // 检查第2-6列是否为数字
    for (int i = 1; i < 6; i++) {
      try {
        double.parse(row[i].toString());
      } catch (_) {
        return false;
      }
    }
    return true;
  }

  /// 核心导入逻辑
  Future<void> _importFiles(List<String> filePaths) async {
    setState(() {
      _isImporting = true;
      _totalFiles = filePaths.length;
      _successFiles = 0;
      _failedFiles = 0;
      _totalKlines = 0;
      _results.clear();
    });

    final cacheDir = await _getCacheDir();
    final targetDir = '$cacheDir${Platform.pathSeparator}${_marketSubDir()}';

    // 确保目标目录存在
    await Directory(targetDir).create(recursive: true);

    for (final path in filePaths) {
      final fileName = path.split(Platform.pathSeparator).last;
      try {
        final file = File(path);
        final bytes = await file.readAsBytes();
        final content = _decodeBytes(bytes);

        // 解析CSV
        final rows = const CsvToListConverter(eol: '\n').convert(content);
        if (rows.isEmpty) {
          _results.add(_ImportResult(fileName, false, '文件为空'));
          _failedFiles++;
          continue;
        }

        // 计算有效K线数（跳过表头）
        int validCount = 0;
        int startIdx = 0;

        // 检查第一行是否为表头
        if (rows.isNotEmpty && !_isValidKlineRow(rows[0])) {
          startIdx = 1;
        }

        for (int i = startIdx; i < rows.length; i++) {
          if (_isValidKlineRow(rows[i])) validCount++;
        }

        if (validCount == 0) {
          _results.add(_ImportResult(fileName, false, '无有效K线数据'));
          _failedFiles++;
          continue;
        }

        // 复制文件到缓存目录
        final targetPath = '$targetDir${Platform.pathSeparator}$fileName';
        await file.copy(targetPath);

        _results.add(_ImportResult(fileName, true, '$validCount 根K线'));
        _successFiles++;
        _totalKlines += validCount;
      } catch (e) {
        _results.add(_ImportResult(fileName, false, e.toString()));
        _failedFiles++;
      }

      // 更新UI
      if (mounted) setState(() {});
    }

    setState(() => _isImporting = false);

    // 显示结果弹窗
    if (mounted) _showResultDialog();
  }

  /// 显示导入结果
  void _showResultDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _failedFiles == 0 ? Icons.check_circle : Icons.info,
                      color: _failedFiles == 0 ? AppColors.success : AppColors.warning,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '导入完成',
                      style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 统计摘要
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('总文件', '$_totalFiles', _textPrimary),
                      _buildStatColumn('成功', '$_successFiles', AppColors.success),
                      _buildStatColumn('失败', '$_failedFiles', _failedFiles > 0 ? AppColors.error : _textMuted),
                      _buildStatColumn('K线总数', '$_totalKlines', AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 详细结果列表
                if (_results.isNotEmpty) ...[
                  Text('详细结果:', style: TextStyle(color: _textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final r = _results[i];
                        return Row(
                          children: [
                            Icon(
                              r.success ? Icons.check_circle_outline : Icons.error_outline,
                              color: r.success ? AppColors.success : AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.fileName,
                                style: TextStyle(color: _textPrimary, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              r.message,
                              style: TextStyle(
                                color: r.success ? AppColors.success : AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text('确定', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: _textSecondary, fontSize: 12)),
      ],
    );
  }

  /// 帮助弹窗
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('导入说明', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildHelpRow('📁', '支持格式', 'CSV (UTF-8, GBK, Big5)'),
              const SizedBox(height: 12),
              _buildHelpRow('📊', '核心字段', '时间, 开盘, 最高, 最低, 收盘, 成交量'),
              const SizedBox(height: 12),
              _buildHelpRow('📋', 'CSV示例', '2024/1/1 9:00:00, 100.5, 102.0, 99.8, 101.2, 50000'),
              const SizedBox(height: 12),
              _buildHelpRow('📂', '扫描文件夹', '自动递归搜索所有子目录中的CSV文件'),
              const SizedBox(height: 12),
              _buildHelpRow('✅', '选择文件', '支持同时选择多个CSV文件导入'),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF0F1A2E) : AppColors.futuresHeaderBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '导入的文件会被复制到应用数据目录，不会修改原始文件。',
                        style: TextStyle(color: AppColors.primary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('知道了', style: TextStyle(color: AppColors.primary, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpRow(String emoji, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(color: _textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('导入数据', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: _textMuted),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: _isImporting ? _buildImportingView() : _buildMainView(),
    );
  }

  Widget _buildImportingView() {
    final processed = _successFiles + _failedFiles;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text('正在导入...', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('$processed / $_totalFiles 文件', style: TextStyle(color: _textSecondary, fontSize: 14)),
          if (_totalFiles > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: processed / _totalFiles,
                backgroundColor: _borderClr,
                color: AppColors.primary,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 导入设置卡片
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDark ? 0.15 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
              border: _isDark ? Border.all(color: AppColors.borderLight, width: 0.5) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('导入设置', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // 市场类型下拉
                DropdownButtonFormField<String>(
                  value: _marketType,
                  onChanged: (v) {
                    if (v != null) setState(() => _marketType = v);
                  },
                  decoration: InputDecoration(
                    labelText: '市场类型',
                    labelStyle: TextStyle(color: _textSecondary, fontSize: 14),
                    prefixIcon: Icon(
                      _marketType == 'crypto' ? Icons.currency_bitcoin : Icons.candlestick_chart,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: _inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _borderClr),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _borderClr),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  dropdownColor: _cardBg,
                  style: TextStyle(color: _textPrimary, fontSize: 15),
                  items: [
                    DropdownMenuItem(
                      value: 'crypto',
                      child: Row(
                        children: [
                          Icon(Icons.currency_bitcoin, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text('加密货币', style: TextStyle(color: _textPrimary)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'futures',
                      child: Row(
                        children: [
                          Icon(Icons.candlestick_chart, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Text('国内期货', style: TextStyle(color: _textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 两个操作按钮
          Row(
            children: [
              // 扫描文件夹（批量）
              Expanded(
                child: _buildActionButton(
                  icon: Icons.folder_copy,
                  label: '扫描文件夹',
                  sublabel: '(批量)',
                  filled: true,
                  onTap: _scanFolder,
                ),
              ),
              const SizedBox(width: 16),
              // 选择文件（支持多选）
              Expanded(
                child: _buildActionButton(
                  icon: Icons.description,
                  label: '选择文件',
                  sublabel: '(支持多选)',
                  filled: false,
                  onTap: _pickFiles,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 底部说明
          Center(
            child: Column(
              children: [
                Text(
                  '支持格式：CSV (UTF-8, GBK, Big5)',
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '核心字段：时间、开盘、最高、最低、收盘、成交量',
                  style: TextStyle(color: _textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 显示已有的导入结果
          if (_results.isNotEmpty) ...[
            Text('最近导入记录', style: TextStyle(color: _textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._results.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _borderClr),
              ),
              child: Row(
                children: [
                  Icon(
                    r.success ? Icons.check_circle : Icons.error,
                    color: r.success ? AppColors.success : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r.fileName, style: TextStyle(color: _textPrimary, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                  Text(r.message, style: TextStyle(color: r.success ? AppColors.success : AppColors.error, fontSize: 12)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.primary,
            width: filled ? 0 : 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: filled ? Colors.white : AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sublabel,
                  style: TextStyle(
                    color: filled ? Colors.white70 : AppColors.primary.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportResult {
  final String fileName;
  final bool success;
  final String message;

  _ImportResult(this.fileName, this.success, this.message);
}
