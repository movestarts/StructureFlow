import 'package:flutter/material.dart';
import '../../services/data_service.dart';
import '../../models/kline_model.dart';
import 'main_screen.dart';
import 'package:intl/intl.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Config
  DateTime? _selectedDate;
  int _sessionLength = 100; // Default
  String _customLength = "";
  bool _isLoading = true;
  String? _error;

  // Data
  List<KlineModel> _allData = [];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // In real app, might want to pick file. Here we hardcode AL.csv path ??
      // User said "AL.csv就是示例数据文件". User path d:/code/trend/AL.csv
      // But we are in Flutter App. 
      // Platform: Windows. We can read file from absolute path d:/code/trend/AL.csv.
      // Need to handle if file missing.
      
      final service = DataService();
      // Using absolute path for testing as requested by user env
      final data = await service.loadFromCsv('d:/code/trend/AL.csv');
      
      if (mounted) {
        setState(() {
          _allData = data;
          _isLoading = false;
          if (data.isNotEmpty) {
            _selectedDate = data.first.time;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: Center(child: Text("Error: $_error")));

    return Scaffold(
      appBar: AppBar(title: const Text("新复盘会话配置")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("1. 选择起始时间", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_allData.isNotEmpty)
              Text("数据范围: ${DateFormat('yyyy-MM-dd').format(_allData.first.time)} 至 ${DateFormat('yyyy-MM-dd').format(_allData.last.time)}"),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final start = _allData.first.time;
                final end = _allData.last.time;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: start,
                  firstDate: start,
                  lastDate: end,
                );
                if (picked != null) {
                  // Find nearest data point
                  final nearest = _allData.firstWhere(
                    (k) => k.time.isAfter(picked.subtract(const Duration(seconds: 1))),
                    orElse: () => _allData.first
                  );
                  setState(() {
                    _selectedDate = nearest.time;
                  });
                }
              },
              child: Text(_selectedDate == null ? "选择日期" : "当前选择: ${DateFormat('yyyy-MM-dd HH:mm').format(_selectedDate!)}"),
            ),
            
            const SizedBox(height: 30),
            const Text("2. 选择复盘长度 (根数)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                _buildRadio(100, "100根"),
                _buildRadio(200, "200根"),
                _buildRadio(300, "300根"),
                _buildRadio(-1, "全部"),
              ],
            ),
            // Custom input
            TextField(
              decoration: const InputDecoration(labelText: "自定义根数 (可选)"),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                _customLength = v;
                if (v.isNotEmpty) {
                  setState(() => _sessionLength = 0); // 0 means custom
                }
              },
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _startSession,
                child: const Text("开始复盘", style: TextStyle(fontSize: 20)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(int val, String label) {
    return Row(
      children: [
        Radio<int>(
          value: val, 
          groupValue: _sessionLength, 
          onChanged: (v) => setState(() => _sessionLength = v!)
        ),
        Text(label),
        const SizedBox(width: 10),
      ],
    );
  }

  void _startSession() {
    if (_selectedDate == null) return;
    
    // Calculate Setup
    int startIndex = _allData.indexWhere((k) => k.time.isAtSameMomentAs(_selectedDate!) || k.time.isAfter(_selectedDate!));
    if (startIndex == -1) startIndex = 0;

    int? limit;
    if (_sessionLength > 0) {
      limit = _sessionLength;
    } else if (_sessionLength == 0 && _customLength.isNotEmpty) {
      limit = int.tryParse(_customLength);
    } 
    // If -1 or null, limit remains null (All)

    Navigator.push(context, MaterialPageRoute(builder: (_) => MainScreen(
      allData: _allData,
      startIndex: startIndex,
      limit: limit,
    )));
  }
}
