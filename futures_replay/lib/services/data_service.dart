import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';

import '../models/kline_model.dart';
import '../models/period.dart';

class DataService {
  
  /// Loads K-line data from a local CSV file.
  Future<List<KlineModel>> loadFromCsv(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception("File not found: $path");
    }

    final input = file.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const CsvToListConverter(eol: '\n'))
        .toList();

    // Assuming first row might be header if it contains non-numeric
    // But user sample: "2009/3/27..." is data. 
    // We check if first row[1] is double.
    
    List<KlineModel> klines = [];
    
    for (int i = 0; i < fields.length; i++) {
      var row = fields[i];
      if (row.isEmpty) continue;
      
      // Skip header if exists
      if (i == 0) {
        try {
          double.parse(row[1].toString());
        } catch (_) {
          continue; // Likely header
        }
      }

      try {
        klines.add(KlineModel.fromList(row));
      } catch (e) {
        print("Skipping error row $i: $row. Error: $e");
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
