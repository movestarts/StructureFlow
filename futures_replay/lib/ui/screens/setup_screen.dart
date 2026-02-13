import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/data_service.dart';
import '../../models/kline_model.dart';
import '../../models/period.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'main_screen.dart';
import 'package:intl/intl.dart';

class SetupScreen extends StatefulWidget {
  final TrainingType trainingType;

  const SetupScreen({Key? key, required this.trainingType}) : super(key: key);

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

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _countController = TextEditingController(text: '100');

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
          // 从文件名提取品种代码
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
      final data = await service.loadFromCsv(path);

      if (mounted) {
        setState(() {
          _allData = data;
          _isLoading = false;
          if (data.isNotEmpty) {
            _selectedDate = data.last.time; // 默认选最后的日期
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('多空复盘配置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            onPressed: () {
              setState(() {
                _allData = [];
                _selectedFilePath = null;
                _selectedFileName = null;
                _error = null;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
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
          decoration: InputDecoration(
            labelText: '交易品种',
            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
            suffixIcon: _allData.isEmpty
                ? IconButton(
                    icon: const Icon(Icons.folder_open, color: AppColors.textMuted),
                    onPressed: _pickFile,
                    tooltip: '选择CSV数据文件',
                  )
                : const Icon(Icons.check_circle, color: AppColors.success),
            hintText: '输入品种代码后选择文件',
          ),
          onChanged: (v) => setState(() => _instrumentCode = v),
        ),
        const SizedBox(height: 8),
        if (_selectedFileName != null && _allData.isEmpty)
          _buildLoadingIndicator()
        else if (_selectedFileName == null && _allData.isEmpty)
          InkWell(
            onTap: _pickFile,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text('点击选择 CSV 数据文件', style: TextStyle(color: AppColors.primary, fontSize: 14)),
                ],
              ),
            ),
          ),
        if (_allData.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bar_chart, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _instrumentCode.isNotEmpty ? _instrumentCode : _selectedFileName ?? '',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('yyyy.MM.dd HH:mm').format(_allData.first.time)} - ${DateFormat('yyyy.MM.dd HH:mm').format(_allData.last.time)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
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

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('加载数据中...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: Period.values.map((p) {
          final isSelected = _selectedPeriod == p;
          return InkWell(
            onTap: () => setState(() => _selectedPeriod = p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : p != Period.values.last
                        ? const Border(bottom: BorderSide(color: AppColors.border, width: 0.5))
                        : null,
                borderRadius: isSelected ? BorderRadius.circular(12) : null,
              ),
              child: Row(
                children: [
                  Text(
                    p.label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
                // 同时选择时间
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
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 12),
            Text(
              _selectedDate != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate!)
                  : '选择起始时间',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCountInput() {
    return TextField(
      controller: _countController,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        hintText: '输入K线根数',
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
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.borderLight,
                ),
              ),
              child: Text(
                labels[i],
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
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
            color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.borderLight,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
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
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '多空合约模式 (高风险高收益)',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enableStopLoss,
            onChanged: (v) => setState(() => _enableStopLoss = v),
            activeColor: AppColors.primary,
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
              side: const BorderSide(color: AppColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '取消',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
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
              disabledBackgroundColor: AppColors.bgSurface,
            ),
            child: Text(
              _allData.isEmpty ? '请先选择数据' : '开始训练',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    // -1 means MAX (no limit)

    final bool isSpotOnly = widget.trainingType == TrainingType.spotReplay ||
        widget.trainingType == TrainingType.spotRandom ||
        widget.trainingType == TrainingType.spotNakedK;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MainScreen(
          allData: _allData,
          startIndex: startIndex,
          limit: limit,
          instrumentCode: _instrumentCode,
          initialPeriod: _selectedPeriod,
          spotOnly: isSpotOnly,
        ),
      ),
    );
  }
}
