import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

class KlineModel extends Equatable {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const KlineModel({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Factory to create from a standard list row (e.g. from CSV)
  /// Expected format: [datetime_string, open, high, low, close, volume]
  factory KlineModel.fromList(List<dynamic> row) {
    if (row.length < 6) {
      throw FormatException("Invalid Kline row data: $row");
    }

    // Parsing datetime: 2009/3/27 9:00:00
    // Try standard parsing, or custom formatted if needed.
    // The input might be string or dynamic.
    DateTime t;
    if (row[0] is DateTime) {
      t = row[0];
    } else {
      String tStr = row[0].toString();
      // Use DateFormat to handle slash separators if DateTime.parse fails
      try {
        // Attempt standard ISO first, but it likely fails with slashes
        t = DateTime.parse(tStr.replaceAll('/', '-'));
      } catch (_) {
         // Fallback usually not needed if we replace / with -, but let's be safe
         // Note: the example has "2009/3/27 9:00:00"
         // DateTime.parse handles "2009-03-27 09:00:00" fine.
         // Single digit month/day might strictly need padding for ISO 8601,
         // but DateTime.parse can be picky.
         // We will use DateFormat from intl package for safety.
         final fmt = DateFormat("yyyy/M/d H:m:s");
         t = fmt.parse(tStr);
      }
    }

    return KlineModel(
      time: t,
      open: double.parse(row[1].toString()),
      high: double.parse(row[2].toString()),
      low: double.parse(row[3].toString()),
      close: double.parse(row[4].toString()),
      volume: double.parse(row[5].toString()),
    );
  }

  /// Copy with override
  KlineModel copyWith({
    DateTime? time,
    double? open,
    double? high,
    double? low,
    double? close,
    double? volume,
  }) {
    return KlineModel(
      time: time ?? this.time,
      open: open ?? this.open,
      high: high ?? this.high,
      low: low ?? this.low,
      close: close ?? this.close,
      volume: volume ?? this.volume,
    );
  }

  @override
  List<Object?> get props => [time, open, high, low, close, volume];

  @override
  String toString() {
    return 'Kline(t: $time, o: $open, h: $high, l: $low, c: $close, v: $volume)';
  }
}
