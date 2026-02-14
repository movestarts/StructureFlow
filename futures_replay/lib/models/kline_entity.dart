
import 'package:isar/isar.dart';

part 'kline_entity.g.dart';

@collection
class KlineEntity {
  // Composite unique ID is tricky in Isar (need to hash string to int or use autoIncrement)
  // We can use autoIncrement id, but index the fields we query.
  Id id = Isar.autoIncrement; 

  @Index(composite: [CompositeIndex('time'), CompositeIndex('period')])
  late String symbol; // e.g. "BTC", "RB"

  late String period; // e.g. "m5", "d1" for filtering

  @Index()
  late int time; // DateTime.millisecondsSinceEpoch

  late double open;
  late double high;
  late double low;
  late double close;
  late double volume;
}
