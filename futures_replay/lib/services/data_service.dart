import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/kline_model.dart';
import '../models/period.dart';
import 'database_service.dart';

class DataService {
  final DatabaseService _db = DatabaseService();

  /// Loads K-line data.
  /// 1. Checks if data exists in DB for [symbol] and detected period.
  /// 2. If yes, returns DB data (fast).
  /// 3. If no, reads CSV, detects period, saves to DB, returns data.
  /// 
  /// [forceRefresh] if true, ignores DB and re-imports from CSV.
  Future<List<KlineModel>> loadWithCache(String path, String symbol, {bool forceRefresh = false}) async {
    // 1. Peek at CSV to detect period (needed for DB query key)
    final periodStr = await _detectPeriodFromCsv(path);
    if (periodStr == null) {
      // Empty or invalid CSV
      return [];
    }

    // 2. Check DB
    if (!forceRefresh) {
      // Try to load from DB
      final dbData = await _db.getKlines(symbol, periodStr);
      if (dbData.isNotEmpty) {
        debugPrint("Loaded ${dbData.length} bars from DB for $symbol ($periodStr)");
        return dbData;
      }
    }

    // 3. Load from CSV (Slow)
    debugPrint("Loading from CSV: $path with period detection: $periodStr");
    final csvData = await loadFromCsv(path);
    if (csvData.isEmpty) return [];

    // 4. Save to DB 
    // We await this so the user doesn't kill the app before save completes, 
    // ensuring next load is fast.
    debugPrint("Saving ${csvData.length} bars to DB...");
    await _db.saveKlines(symbol, periodStr, csvData);
    debugPrint("Saved to DB.");

    return csvData;
  }

  Future<String?> _detectPeriodFromCsv(String path) async {
    try {
      final file = File(path);
      // Read first 10 rows to find valid dates
      final lines = await file.openRead().transform(utf8.decoder).transform(const LineSplitter()).take(10).toList();
      
      if (lines.length < 2) return 'm5'; // Default

      DateTime? t1, t2;
      final fmt1 = DateFormat("yyyy/M/d H:m:s");
      final fmt2 = DateFormat("yyyy/M/d H:m");

      for (var line in lines) {
        final row = line.split(',');
        if (row.length < 2) continue;
        
        String tStr = row[0];
        DateTime? t;
        
        // Try parsing
        // Check if first char is digit to strictly avoid header
        if (tStr.isEmpty || !RegExp(r'^\d').hasMatch(tStr)) continue;

        try {
           t = DateTime.parse(tStr.replaceAll('/', '-'));
        } catch (_) {
           try { t = fmt1.parse(tStr); } catch (_) { 
             try { t = fmt2.parse(tStr); } catch (_) {}
           }
        }
        
        if (t != null) {
          if (t1 == null) {
            t1 = t;
          } else {
            t2 = t;
            // Check if t2 > t1
            if (t2.isAfter(t1)) {
               break;
            } else {
               // Maybe unsorted or same time? keep looking
               continue;
            }
          }
        }
      }

      if (t1 != null && t2 != null) {
        final diff = t2.difference(t1).inMinutes;
        if (diff == 1) return 'm1';
        if (diff == 5) return 'm5';
        if (diff == 15) return 'm15';
        if (diff == 30) return 'm30';
        if (diff == 60) return 'h1';
        if (diff == 1440) return 'd1';
        // Fallbacks
        if (diff > 0) return 'm$diff';
      }
    } catch (e) {
      debugPrint("Error detecting period: $e");
    }
    return 'm5'; // Default fallback
  }

  /// Loads K-line data from a local CSV file.
  Future<List<KlineModel>> loadFromCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception("File not found: $path");
    }

    List<KlineModel> klines = [];
    
    // Performance optimization: 
    // 1. Stream processing (reading line by line) instead of loading full file.
    // 2. Manual parsing instead of CsvToListConverter (faster for simple numeric data).
    // 3. Reuse DateFormat (avoid creating it per row).
    // 4. Periodically yield to event loop (Future.delayed) to prevent UI freeze.

    final fmt1 = DateFormat("yyyy/M/d H:m:s");
    final fmt2 = DateFormat("yyyy/M/d H:m");

    Stream<String> lines = file.openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

    int count = 0;
    
    await for (final line in lines) {
      count++;
      if (line.trim().isEmpty) continue;

      // Yield every 2000 lines to prevent UI freeze
      if (count % 2000 == 0) {
        await Future.delayed(Duration.zero);
      }

      // Manual split is faster for standard CSV without complex quoting
      final row = line.split(',');
      if (row.length < 6) continue;

      try {
        // Validation: verify 2nd column (Open) is a number. 
        // This effectively skips the header row if present.
        double? open = double.tryParse(row[1]);
        if (open == null) continue;

        String tStr = row[0];
        DateTime time;
        
        // Fast date parsing
        try {
           // Try fast path first (DateTime.parse with / replaced)
           time = DateTime.parse(tStr.replaceAll('/', '-'));
        } catch (_) {
           // Fallback to explicit formats
           try {
             time = fmt1.parse(tStr);
           } catch (_) {
             time = fmt2.parse(tStr);
           }
        }

        klines.add(KlineModel(
          time: time,
          open: open,
          high: double.parse(row[2]),
          low: double.parse(row[3]),
          close: double.parse(row[4]),
          volume: double.parse(row[5]),
        ));

      } catch (e) {
        // Skip malformed lines
        if (klines.isEmpty && count < 10) {
          print("Skipping error row $count: $line. Error: $e");
        }
      }
    }

    return klines;
  }

  /// Aggregates 5m ticks into a larger period (15m, 30m, 60m).
  /// 
  /// Source Must be 5m data.
  /// Strictly aligns to the period boundaries.
  /// E.g. 15m bar starts at 9:00, 9:15, 9:30...
  List<KlineModel> aggregate(List<KlineModel> source, Period period) {
    if (period == Period.m5) return source;

    List<KlineModel> result = [];
    if (source.isEmpty) return result;

    KlineModel? currentBar;
    
    // Helper to snap time to period start
    // e.g. 9:05 for 15m -> 9:00
    // But be careful: futures markets might have strict sessions.
    // For simplicity in this logical aggregation, we bucket by time modulus.
    
    // We assume data is sorted.
    
    for (var k in source) {
      if (currentBar == null) {
        currentBar = k;
        // Adjust time to period start? 
        // Typically, bar time is the OPEN time.
        // If 5m bars are 9:00, 9:05, 9:10 -> These 3 form the 9:00 15m bar.
        // We need to check if 'k' belongs to the 'currentBar' bucket.
        continue;
      }

      // Check boundary
      if (_isSamePeriod(currentBar.time, k.time, period)) {
        // Merge
        currentBar = currentBar.copyWith(
          high: k.high > currentBar.high ? k.high : currentBar.high,
          low: k.low < currentBar.low ? k.low : currentBar.low,
          close: k.close,
          volume: currentBar.volume + k.volume,
          // Open remains currentBar.open
          // Time remains currentBar.time
        );
      } else {
        // Finalize old bar
        result.add(currentBar);
        // Start new
        currentBar = k; // The time of the 5m bar becomes the start of the new big bar
      }
    }

    if (currentBar != null) {
      result.add(currentBar);
    }

    return result;
  }

  bool _isSamePeriod(DateTime start, DateTime current, Period p) {
    // Calculate the period start time for both timestamps
    // This handles hour/day boundaries correctly
    
    final periodMinutes = p.minutes;
    
    // Get total minutes since epoch for both times
    final startTotalMinutes = start.year * 525600 + 
                              start.month * 43800 + 
                              start.day * 1440 + 
                              start.hour * 60 + 
                              start.minute;
    
    final currentTotalMinutes = current.year * 525600 + 
                                current.month * 43800 + 
                                current.day * 1440 + 
                                current.hour * 60 + 
                                current.minute;
    
    // Calculate which period bucket each belongs to
    final startBucket = startTotalMinutes ~/ periodMinutes;
    final currentBucket = currentTotalMinutes ~/ periodMinutes;
    
    return startBucket == currentBucket;
  }
}
