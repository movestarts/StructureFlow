import 'package:flutter_test/flutter_test.dart';
import 'package:futures_replay/models/kline_model.dart';
import 'package:futures_replay/models/period.dart';
import 'package:futures_replay/services/data_service.dart';

void main() {
  group('DataService Aggregation', () {
    final service = DataService();

    test('Aggregate 5m to 15m simple case', () {
      // Create 3 5m bars: 9:00, 9:05, 9:10
      final k1 = KlineModel(time: DateTime(2023, 1, 1, 9, 0), open: 10, high: 12, low: 9, close: 11, volume: 100);
      final k2 = KlineModel(time: DateTime(2023, 1, 1, 9, 5), open: 11, high: 15, low: 11, close: 14, volume: 200);
      final k3 = KlineModel(time: DateTime(2023, 1, 1, 9, 10), open: 14, high: 14, low: 8, close: 10, volume: 100);
      
      final source = [k1, k2, k3];
      final result = service.aggregate(source, Period.m15);
      
      expect(result.length, 1);
      final bar = result.first;
      
      expect(bar.time, k1.time);
      expect(bar.open, 10.0);
      expect(bar.high, 15.0); // k2 high
      expect(bar.low, 8.0);   // k3 low
      expect(bar.close, 10.0); // k3 close
      expect(bar.volume, 400.0);
    });

    test('Aggregate across boundary', () {
      // 9:10 (belongs to 9:00-9:15), 9:15 (belongs to 9:15-9:30)
      final k1 = KlineModel(time: DateTime(2023, 1, 1, 9, 10), open: 10, high: 12, low: 9, close: 11, volume: 100);
      final k2 = KlineModel(time: DateTime(2023, 1, 1, 9, 15), open: 11, high: 13, low: 10, close: 12, volume: 100);
      
      final source = [k1, k2];
      final result = service.aggregate(source, Period.m15);
      
      expect(result.length, 2);
      expect(result[0].time, DateTime(2023, 1, 1, 9, 10)); // Start of first chunk available
      expect(result[1].time, DateTime(2023, 1, 1, 9, 15));
    });
  });
}
