
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/kline_entity.dart';
import '../models/kline_model.dart';
import '../models/period.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  late Isar _isar;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    final dir = await getApplicationDocumentsDirectory();
    
    // Check if we need to migrate from old structure or just new
    // For now, just open the instance
    if (Isar.instanceNames.isEmpty) {
      _isar = await Isar.open(
        [KlineEntitySchema],
        directory: dir.path,
        inspector: true, // Allow easy debugging
      );
    } else {
      _isar = Isar.getInstance()!;
    }
    
    _isInitialized = true;
  }

  /// Bulk import klines. 
  /// This is much faster than inserting one by one.
  Future<void> saveKlines(String symbol, String period, List<KlineModel> data) async {
    if (!_isInitialized) await init();

    if (data.isEmpty) return;

    // Convert models to entities
    final entities = data.map((d) {
      return KlineEntity()
        ..symbol = symbol
        ..period = period
        ..time = d.time.millisecondsSinceEpoch
        ..open = d.open
        ..high = d.high
        ..low = d.low
        ..close = d.close
        ..volume = d.volume;
    }).toList();

    // Use a synchronous transaction for maximum speed if possible, but writeTxn is async
    await _isar.writeTxn(() async {
      // Clear existing data for this symbol/period overlap?
      // Or just put. If we use autoIncrement, we get duplicates if we don't check.
      // To avoid duplicates, we should delete old data for this symbol/period range first.
      
      final start = data.first.time.millisecondsSinceEpoch;
      final end = data.last.time.millisecondsSinceEpoch;

      // Delete existing in range to avoid duplication
      await _isar.klineEntitys
          .filter()
          .symbolEqualTo(symbol)
          .and()
          .periodEqualTo(period)
          .and()
          .timeBetween(start, end)
          .deleteAll();

      // Batch put
      await _isar.klineEntitys.putAll(entities);
    });
  }

  /// Get Klines from DB.
  /// Returns empty list if not found.
  Future<List<KlineModel>> getKlines(String symbol, String period, {int? start, int? end, int? limit}) async {
    if (!_isInitialized) await init();

    var query = _isar.klineEntitys
        .filter()
        .symbolEqualTo(symbol)
        .and()
        .periodEqualTo(period);

    // Apply time range if provided
    if (start != null && end != null) {
      query = query.and().timeBetween(start, end);
    } else if (start != null) {
      query = query.and().timeGreaterThan(start);
    } 

    // Sort by time
    // We used a composite index, so sorting by time should be implicit if we use the index correctly
    // or we explicit sort.
    var qBuilder = query.sortByTime();

    if (limit != null) {
      // Isar doesn't have limit() on QueryBuilder directly in early chain usually,
      // it's on findAll(). findAll(limit: 100)
      // limit is handled in findAll
    }

    // Execute

    // Execute
    final entities = limit != null 
        ? await qBuilder.limit(limit).findAll()
        : await qBuilder.findAll();

    return entities.map((e) => KlineModel(
      time: DateTime.fromMillisecondsSinceEpoch(e.time),
      open: e.open,
      high: e.high,
      low: e.low,
      close: e.close,
      volume: e.volume,
    )).toList();
  }

  /// Check if we have data for this symbol
  Future<bool> hasData(String symbol, String period) async {
    if (!_isInitialized) await init();

    final count = await _isar.klineEntitys
        .filter()
        .symbolEqualTo(symbol)
        .and()
        .periodEqualTo(period)
        .count();
    
    return count > 0;
  }
  
  Future<void> clearAll() async {
     if (!_isInitialized) await init();
     await _isar.writeTxn(() async {
       await _isar.clear();
     });
  }
}
