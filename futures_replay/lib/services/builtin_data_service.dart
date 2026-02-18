import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../models/kline_model.dart';
import 'database_service.dart';

/// Service to manage built-in sample data
class BuiltinDataService {
  static const String _keyDataImported = 'builtin_data_imported_v1';
  
  final DatabaseService _db = DatabaseService();
  
  /// Check if built-in data has been imported
  Future<bool> isDataImported() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDataImported) ?? false;
  }
  
  /// Import built-in data (RB2505 and M2505) into database
  /// Only imports if not already done
  Future<void> importIfNeeded() async {
    if (await isDataImported()) {
      debugPrint('[BuiltinData] Already imported, skipping');
      return;
    }
    
    debugPrint('[BuiltinData] Starting import...');
    await import();
    debugPrint('[BuiltinData] Import completed');
  }
  
  /// Force import built-in data
  Future<void> import() async {
    try {
      // Import RB2505 (螺纹钢主连)
      await _importAsset(
        'assets/data/RB2505.csv',
        'RB2505',
        '螺纹钢主连',
      );
      
      // Import M2505 (豆粕主连)
      await _importAsset(
        'assets/data/M2505.csv',
        'M2505',
        '豆粕主连',
      );
      
      // Mark as imported
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDataImported, true);
      
      debugPrint('[BuiltinData] ✓ All built-in data imported successfully');
    } catch (e) {
      debugPrint('[BuiltinData] ✗ Import failed: $e');
      rethrow;
    }
  }
  
  Future<void> _importAsset(String assetPath, String symbol, String name) async {
    debugPrint('[BuiltinData] Importing $name ($symbol)...');
    
    // Check if already exists in DB
    final hasData = await _db.hasData(symbol, 'm5');
    if (hasData) {
      debugPrint('[BuiltinData] $name already in DB, skipping');
      return;
    }
    
    // Load CSV from assets
    final csvString = await rootBundle.loadString(assetPath);
    final lines = const LineSplitter().convert(csvString);
    
    if (lines.isEmpty) {
      debugPrint('[BuiltinData] $name: empty file');
      return;
    }
    
    // Parse CSV
    final data = <KlineModel>[];
    bool isHeader = true;
    
    for (final line in lines) {
      if (isHeader) {
        isHeader = false;
        continue; // Skip header
      }
      
      final parts = line.split(',');
      if (parts.length < 6) continue;
      
      try {
        final time = DateTime.parse(parts[0]);
        final open = double.parse(parts[1]);
        final high = double.parse(parts[2]);
        final low = double.parse(parts[3]);
        final close = double.parse(parts[4]);
        final volume = double.parse(parts[5]);
        
        data.add(KlineModel(
          time: time,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ));
      } catch (e) {
        debugPrint('[BuiltinData] Failed to parse line: $line, error: $e');
      }
    }
    
    if (data.isEmpty) {
      debugPrint('[BuiltinData] $name: no valid data');
      return;
    }
    
    // Save to database
    debugPrint('[BuiltinData] Saving ${data.length} bars of $name to DB...');
    await _db.saveKlines(symbol, 'm5', data);
    debugPrint('[BuiltinData] ✓ $name imported (${data.length} bars)');
  }
  
  /// Clear imported flag (for testing/debugging)
  Future<void> resetImportFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDataImported);
    debugPrint('[BuiltinData] Import flag reset');
  }
  
  /// Get list of built-in symbols
  List<BuiltinSymbol> getBuiltinSymbols() {
    return [
      BuiltinSymbol(
        symbol: 'RB2505',
        name: '螺纹钢主连',
        period: 'm5',
        description: '2025年1月至2月数据，约18000根K线',
      ),
      BuiltinSymbol(
        symbol: 'M2505',
        name: '豆粕主连',
        period: 'm5',
        description: '2026年1月数据，约2000根K线',
      ),
    ];
  }
}

class BuiltinSymbol {
  final String symbol;
  final String name;
  final String period;
  final String description;
  
  BuiltinSymbol({
    required this.symbol,
    required this.name,
    required this.period,
    required this.description,
  });
}
