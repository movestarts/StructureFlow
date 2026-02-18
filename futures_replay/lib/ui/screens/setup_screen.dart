import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io'; // Added
import 'package:path_provider/path_provider.dart'; // Added
import '../../services/data_service.dart';
import '../../services/database_service.dart';
import '../../services/builtin_data_service.dart';
import '../../models/kline_model.dart';
import '../../models/period.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'main_screen.dart';
import 'package:intl/intl.dart';

class SetupScreen extends StatefulWidget {
  final TrainingType trainingType;

  const SetupScreen({super.key, required this.trainingType});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // 市场类型
  int _marketTab = 1; // 0=加密货币, 1=国内期货

  // Config
  DateTime? _selectedDate;
  int _sessionLength = 100;
  Period _selectedPeriod = Period.m5;
  bool _isLoading = false;
  String? _error;
  bool _enableStopLoss = false;
  int _displayMode = 0; // 0=竖屏, 1=横屏

  // Data
  List<KlineModel> _allData = [];
  String? _selectedFilePath;
  String? _selectedFileName;
  String _instrumentCode = '';
  List<File> _cachedFiles = []; // Added

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _loadCachedFiles();
  }

  Future<void> _loadCachedFiles() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      List<File> allFiles = [];

      // 1. Check default ImportData path: Documents/cryptotrainer/csv
      final baseDir = Directory('${appDocDir.path}${Platform.pathSeparator}cryptotrainer${Platform.pathSeparator}csv');
      if (await baseDir.exists()) {
        // Futures
        final futuresDir = Directory('${baseDir.path}${Platform.pathSeparator}futures');
        if (await futuresDir.exists()) {
          allFiles.addAll(futuresDir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.csv')));
        }
        // Crypto
        final cryptoDir = Directory('${baseDir.path}${Platform.pathSeparator}crypto');
        if (await cryptoDir.exists()) {
          allFiles.addAll(cryptoDir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.csv')));
        }
      }

      // 2. Check simple data_cache (legacy or manual)
      final simpleCacheDir = Directory('${appDocDir.path}${Platform.pathSeparator}data_cache');
      if (await simpleCacheDir.exists()) {
        allFiles.addAll(simpleCacheDir.listSync().whereType<File>().where((f) => f.path.toLowerCase().endsWith('.csv')));
      }

      if (mounted) {
        setState(() {
          _cachedFiles = allFiles;
        });
      }
    } catch (e) {
      debugPrint("加载缓存文件失败: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _countController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: '选择K线数据文件 (CSV格式)',
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFilePath = result.files.single.path;
          _selectedFileName = result.files.single.name;
          _isLoading = true;
          _error = null;
          _instrumentCode = _selectedFileName!
              .replaceAll('.csv', '')
              .replaceAll(RegExp(r'[_\-\d]'), '')
              .toUpperCase();
          _searchController.text = _instrumentCode;
        });

        await _loadData(_selectedFilePath!);
      }
    } catch (e) {
      setState(() {
        _error = "选择文件失败: $e";
        _isLoading = false;
      });
    }
  }


  Future<void> _loadData(String path) async {
    try {
      final service = DataService();
      // Use filename (without extension) as cache key
      final fileName = path.split(Platform.pathSeparator).last;
      final symbol = fileName.replaceAll('.csv', '');
      
      final data = await service.loadWithCache(path, symbol);

      if (mounted) {
        setState(() {
          _allData = data;
          _isLoading = false;
          if (data.isNotEmpty) {
            _selectedDate = data.last.time;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "加载数据失败: $e";
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.lightTextPrimary, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '多空复盘配置',
          style: TextStyle(
            color: AppColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _allData = [];
                _selectedFilePath = null;
                _selectedFileName = null;
                _error = null;
              });
            },
            icon: Icon(Icons.refresh, color: AppColors.primary, size: 18),
            label: Text(
              '刷新数据',
              style: TextStyle(color: AppColors.primary, fontSize: 14),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 市场类型切换
            _buildMarketTabs(),
            const SizedBox(height: 24),

            // 交易品种搜索/选择文件
            _buildInstrumentField(),
            const SizedBox(height: 24),

            // 选择周期
            if (_allData.isNotEmpty) ...[
              _buildSectionLabel('选择周期'),
              const SizedBox(height: 12),
              _buildPeriodSelector(),
              const SizedBox(height: 20),

              // 日期选择
              _buildDateSelector(),
              const SizedBox(height: 20),

              // 训练数量
              _buildSectionLabel('训练数量 (K线根数)'),
              const SizedBox(height: 12),
              _buildCountInput(),
              const SizedBox(height: 12),
              _buildCountChips(),
              const SizedBox(height: 24),

              // 显示模式
              _buildSectionLabel('显示模式'),
              const SizedBox(height: 12),
              _buildDisplayModeSelector(),
              const SizedBox(height: 24),

              // 止盈止损
              _buildStopLossToggle(),
            ],

            const SizedBox(height: 40),

            // 底部按钮
            _buildActionButtons(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketTabs() {
    return Row(
      children: [
        _buildMarketTab(0, '₿  加密货币'),
        const SizedBox(width: 12),
        _buildMarketTab(1, '◆  国内期货'),
      ],
    );
  }

  Widget _buildMarketTab(int index, String label) {
    final isSelected = _marketTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _marketTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.lightBorder,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.lightTextSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstrumentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.lightTextPrimary),
          decoration: InputDecoration(
            labelText: '交易品种',
            labelStyle: const TextStyle(color: AppColors.lightTextSecondary),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.search, color: AppColors.lightTextMuted),
            suffixIcon: _allData.isEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: AppColors.lightTextMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _instrumentCode = '');
                    },
                  )
                : const Icon(Icons.check_circle, color: AppColors.success),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onChanged: (v) => setState(() => _instrumentCode = v),
        ),
        const SizedBox(height: 8),

        // 显示内置数据列表 (优先显示)
        if (_allData.isEmpty && _marketTab == 1)
          _buildBuiltinDataList(),

        // 显示缓存文件列表 (当未选择文件时)
        if (_allData.isEmpty)
          _buildCachedFileList(),

        if (_selectedFileName != null && _allData.isEmpty && _isLoading)
          _buildLoadingIndicator()
        else if (_selectedFileName == null && _allData.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('或 点击选择本地 CSV 文件',
                        style: TextStyle(color: AppColors.primary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        if (_allData.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPeriod.code,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('yyyy.MM.dd HH:mm').format(_allData.first.time)} - ${DateFormat('yyyy.MM.dd HH:mm').format(_allData.last.time)}',
                  style: const TextStyle(color: AppColors.lightTextSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildBuiltinDataList() {
    final builtinService = BuiltinDataService();
    final builtinSymbols = builtinService.getBuiltinSymbols();
    
    if (builtinSymbols.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.star, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '内置示例数据',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: builtinSymbols.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final symbol = builtinSymbols[index];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.data_object, color: AppColors.success, size: 20),
                title: Text(
                  symbol.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  symbol.description,
                  style: const TextStyle(fontSize: 12, color: AppColors.lightTextMuted),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextMuted),
                onTap: () => _loadBuiltinData(symbol),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadBuiltinData(BuiltinSymbol symbol) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _selectedFileName = symbol.name;
    });

    try {
      final db = DatabaseService();
      final data = await db.getKlines(symbol.symbol, symbol.period);

      if (data.isEmpty) {
        setState(() {
          _error = '内置数据为空，请重启应用重新导入';
          _isLoading = false;
          _selectedFileName = null;
        });
        return;
      }

      setState(() {
        _allData = data;
        _instrumentCode = symbol.symbol;
        _searchController.text = symbol.name;
        _isLoading = false;
        _selectedFilePath = null; // 标记为内置数据
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
        _selectedFileName = null;
      });
    }
  }

  Widget _buildCachedFileList() {
    if (_cachedFiles.isEmpty) return const SizedBox.shrink();
    
    final query = _instrumentCode.trim().toUpperCase();
    final matches = _cachedFiles.where((f) {
      final name = f.path.split(Platform.pathSeparator).last.toUpperCase();
      return name.contains(query);
    }).toList();
    
    // 如果有搜索词但无匹配，不显示列表（让用户点击选择文件）
    if (matches.isEmpty && query.isNotEmpty) return const SizedBox.shrink();

    final displayList = matches.isEmpty && query.isEmpty ? _cachedFiles : matches;
    if (displayList.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: AppColors.lightTextSecondary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  '本地缓存文件',
                  style: TextStyle(
                    color: AppColors.lightTextSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: displayList.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, index) {
          final file = displayList[index];
          final filename = file.path.split(Platform.pathSeparator).last;
          final name = filename.replaceAll('.csv', '');
          
          return ListTile(
            dense: true,
            leading: const Icon(Icons.show_chart, color: AppColors.primary, size: 20),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.lightTextMuted),
            onTap: () {
              setState(() {
                _selectedFilePath = file.path;
                _selectedFileName = filename;
                _instrumentCode = name.toUpperCase();
                _searchController.text = _instrumentCode;
                _isLoading = true;
                _error = null;
              });
              // Hide keyboard
              FocusScope.of(context).unfocus();
              _loadData(file.path);
            },
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
          SizedBox(width: 10),
          Text('加载数据中...', style: TextStyle(color: AppColors.lightTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        children: Period.values.map((p) {
          final isSelected = _selectedPeriod == p;
          return InkWell(
            onTap: () => setState(() => _selectedPeriod = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.06) : Colors.transparent,
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : p != Period.values.last
                        ? const Border(bottom: BorderSide(color: AppColors.lightDivider, width: 0.5))
                        : null,
                borderRadius: isSelected ? BorderRadius.circular(12) : null,
              ),
              child: Row(
                children: [
                  Text(
                    p.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.lightTextPrimary,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                  if (isSelected)
                    const Icon(Icons.check, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
      onTap: _allData.isEmpty
          ? null
          : () async {
              final start = _allData.first.time;
              final end = _allData.last.time;
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate ?? end,
                firstDate: start,
                lastDate: end,
              );
              if (picked != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_selectedDate ?? end),
                );
                DateTime finalDate = picked;
                if (time != null) {
                  finalDate = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                }
                final nearest = _allData.firstWhere(
                  (k) => k.time.isAfter(finalDate.subtract(const Duration(seconds: 1))),
                  orElse: () => _allData.last,
                );
                setState(() => _selectedDate = nearest.time);
              }
            },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: AppColors.lightTextMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              _selectedDate != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate!)
                  : '选择起始时间',
              style: TextStyle(
                color: AppColors.lightTextPrimary,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_drop_down, color: AppColors.lightTextMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCountInput() {
    return TextField(
      controller: _countController,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.lightTextPrimary),
      decoration: InputDecoration(
        hintText: '输入K线根数',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null && parsed > 0) {
          setState(() => _sessionLength = parsed);
        }
      },
    );
  }

  Widget _buildCountChips() {
    final options = [100, 200, 500, -1];
    final labels = ['100', '200', '500', 'MAX'];
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = _sessionLength == options[i];
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _sessionLength = options[i];
                if (options[i] > 0) {
                  _countController.text = options[i].toString();
                } else {
                  _countController.text = 'MAX';
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.lightBorder,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.lightTextSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDisplayModeSelector() {
    return Row(
      children: [
        _buildDisplayModeOption(0, Icons.stay_current_portrait, '竖屏'),
        const SizedBox(width: 16),
        _buildDisplayModeOption(1, Icons.stay_current_landscape, '横屏'),
      ],
    );
  }

  Widget _buildDisplayModeOption(int value, IconData icon, String label) {
    final isSelected = _displayMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _displayMode = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.lightBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.lightTextMuted, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.lightTextSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopLossToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '启用止盈止损',
                  style: TextStyle(
                    color: AppColors.lightTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '多空合约模式 (高风险高收益)',
                  style: TextStyle(
                    color: AppColors.lightTextMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableStopLoss,
            onChanged: (v) => setState(() => _enableStopLoss = v),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppColors.lightBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.white,
            ),
            child: Text(
              '取消',
              style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _allData.isEmpty ? null : _startSession,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.lightBorder,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _allData.isEmpty ? '请先选择数据' : '开始训练',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  void _startSession() {
    if (_selectedDate == null) return;

    int startIndex = _allData.indexWhere(
      (k) => k.time.isAtSameMomentAs(_selectedDate!) || k.time.isAfter(_selectedDate!),
    );
    if (startIndex == -1) startIndex = 0;

    int? limit;
    if (_sessionLength > 0) {
      limit = _sessionLength;
    }

    final bool isSpotOnly = widget.trainingType == TrainingType.spotReplay ||
        widget.trainingType == TrainingType.spotRandom ||
        widget.trainingType == TrainingType.spotNakedK;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Theme(
          data: AppTheme.darkTheme,
          child: MainScreen(
            allData: _allData,
            startIndex: startIndex,
            limit: limit,
            instrumentCode: _instrumentCode,
            initialPeriod: _selectedPeriod,
            spotOnly: isSpotOnly,
            csvPath: _selectedFilePath,
            initialLandscape: _displayMode == 1, // 1=横屏
          ),
        ),
      ),
    );
  }
}
