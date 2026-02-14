import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_theme.dart';
import '../../services/settings_service.dart';

class DeleteDataScreen extends StatefulWidget {
  const DeleteDataScreen({super.key});

  @override
  State<DeleteDataScreen> createState() => _DeleteDataScreenState();
}

class _DeleteDataScreenState extends State<DeleteDataScreen> {
  bool _isLoading = true;
  List<File> _limitFiles = []; // All files found
  List<File> _filteredFiles = []; // Filtered by search
  final Set<String> _selectedPaths = {};
  final TextEditingController _searchCtrl = TextEditingController();

  // Theme getters
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.bgDark : AppColors.lightBg;
  Color get _cardBg => _isDark ? AppColors.bgCard : Colors.white;
  Color get _textPrimary => _isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  Color get _textSecondary => _isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;
  Color get _textMuted => _isDark ? AppColors.textMuted : AppColors.lightTextMuted;
  Color get _dividerClr => _isDark ? AppColors.borderLight : AppColors.lightDivider;
  Color get _inputFill => _isDark ? AppColors.bgSurface : AppColors.lightSurface;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredFiles = _limitFiles.where((file) {
        final name = file.path.split(Platform.pathSeparator).last.toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    try {
      final settings = context.read<SettingsService>();
      String rootPath;
      if (settings.dataCacheDir.isNotEmpty) {
        rootPath = settings.dataCacheDir;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        rootPath = '${dir.path}${Platform.pathSeparator}cryptotrainer${Platform.pathSeparator}csv';
      }

      final rootDir = Directory(rootPath);
      if (!await rootDir.exists()) {
        setState(() {
          _limitFiles = [];
          _filteredFiles = [];
          _isLoading = false;
        });
        return;
      }

      final List<File> files = [];
      // Search in crypto and futures subdirectories
      final subDirs = ['crypto', 'futures'];
      
      for (final sub in subDirs) {
        final dir = Directory('$rootPath${Platform.pathSeparator}$sub');
        if (await dir.exists()) {
           await for (final entity in dir.list()) {
             if (entity is File && entity.path.toLowerCase().endsWith('.csv')) {
               files.add(entity);
             }
           }
        }
      }
      
      // Sort by name
      files.sort((a, b) {
        final nameA = a.path.split(Platform.pathSeparator).last;
        final nameB = b.path.split(Platform.pathSeparator).last;
        return nameA.compareTo(nameB);
      });

      setState(() {
        _limitFiles = files;
        _filteredFiles = List.from(files);
        _isLoading = false;
      });
      // Re-apply search if any
      if (_searchCtrl.text.isNotEmpty) {
        _onSearchChanged();
      }

    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading files: $e');
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    final count = _selectedPaths.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 48),
              const SizedBox(height: 16),
              Text('确认删除', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('确定要删除选中的 $count 个文件吗？此操作无法撤销。', 
                textAlign: TextAlign.center,
                style: TextStyle(color: _textSecondary, fontSize: 14)
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                   Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _dividerClr),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text('取消', style: TextStyle(color: _textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('删除', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    int successCount = 0;
    for (final path in _selectedPaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          successCount++;
        }
      } catch (e) {
        debugPrint('Failed to delete $path: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('成功删除 $successCount 个文件'), backgroundColor: AppColors.success),
    );

    _selectedPaths.clear();
    _loadFiles();
  }

  void _toggleAll() {
    setState(() {
      final isAllVisibleSelected = _filteredFiles.isNotEmpty && 
          _filteredFiles.every((f) => _selectedPaths.contains(f.path));
      
      if (isAllVisibleSelected) {
        // Deselect all visible
        for (var f in _filteredFiles) {
          _selectedPaths.remove(f.path);
        }
      } else {
        // Select all visible
        for (var f in _filteredFiles) {
          _selectedPaths.add(f.path);
        }
      }
    });
  }

  /// Parse filename to get symbol (e.g. BTC_1d.csv -> BTC)
  String _getSymbol(String filename) {
    if (filename.contains('_')) {
      return filename.split('_').first.toUpperCase();
    }
    if (filename.contains('-')) {
       // Attempt to handle "d1 - BTC..." case from screenshot
       final parts = filename.split('-');
       if (parts.length > 1) {
         return parts[1].trim().split('_').first.toUpperCase();
       }
    }
    return filename.split('.').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final isAllVisibleSelected = _filteredFiles.isNotEmpty && 
        _filteredFiles.every((f) => _selectedPaths.contains(f.path));

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('删除数据', style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isAllVisibleSelected ? Icons.check_box : Icons.check_box_outline_blank, 
              color: isAllVisibleSelected ? AppColors.primary : _textMuted
            ),
            tooltip: '全选',
            onPressed: _toggleAll,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                hintText: '搜索品种、文件名...',
                hintStyle: TextStyle(color: _textMuted),
                prefixIcon: Icon(Icons.search, color: _textMuted),
                filled: true,
                fillColor: _inputFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
              ),
            ),
          ),

          // Status Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.transparent, // Or separate background
            child: Row(
              children: [
                Text(
                  '已选 ${_selectedPaths.length} 项',
                  style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('确认删除'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _inputFill,
                    disabledForegroundColor: _textMuted,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filteredFiles.isEmpty
                ? Center(child: Text('没有找到文件', style: TextStyle(color: _textMuted)))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = _filteredFiles[index];
                      final filename = file.path.split(Platform.pathSeparator).last;
                      final symbol = _getSymbol(filename);
                      final isSelected = _selectedPaths.contains(file.path);

                      return Material(
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPaths.remove(file.path);
                              } else {
                                _selectedPaths.add(file.path);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1), // Example generic color
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  // Try to identify currency vs futures icon
                                  child: Icon(
                                    ['BTC', 'ETH', 'SOL', 'BNB'].contains(symbol) 
                                      ? Icons.currency_bitcoin 
                                      : Icons.show_chart,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        symbol,
                                        style: TextStyle(
                                          color: _textPrimary, 
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        filename,
                                        style: TextStyle(
                                          color: _textSecondary, 
                                          fontSize: 12
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Checkbox
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: isSelected ? AppColors.primary : _textMuted,
                                  size: 24,
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}
