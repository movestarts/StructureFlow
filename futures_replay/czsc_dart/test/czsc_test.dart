import 'package:test/test.dart';
import 'package:czsc_dart/czsc_dart.dart';

void main() {
  group('CZSC Dart Tests', () {
    test('RawBar creation', () {
      final bar = RawBar(
        symbol: 'AAPL',
        id: 0,
        dt: DateTime(2024, 1, 1),
        freq: Freq.d,
        open: 100,
        close: 102,
        high: 105,
        low: 98,
        vol: 1000,
      );

      expect(bar.symbol, equals('AAPL'));
      expect(bar.upper, equals(3)); // 105 - 102
      expect(bar.lower, equals(2)); // 100 - 98
      expect(bar.solid, equals(2)); // |100 - 102|
    });

    test('Remove include relationship', () {
      final k1 = NewBar(
        symbol: 'AAPL',
        id: 0,
        dt: DateTime(2024, 1, 1),
        freq: Freq.d,
        open: 100,
        close: 102,
        high: 105,
        low: 98,
        vol: 1000,
        elements: [],
      );

      final k2 = NewBar(
        symbol: 'AAPL',
        id: 1,
        dt: DateTime(2024, 1, 2),
        freq: Freq.d,
        open: 102,
        close: 108,
        high: 110,
        low: 100,
        vol: 1200,
        elements: [],
      );

      final k3 = RawBar(
        symbol: 'AAPL',
        id: 2,
        dt: DateTime(2024, 1, 3),
        freq: Freq.d,
        open: 108,
        close: 106,
        high: 109,
        low: 103,
        vol: 800,
      );

      final result = removeInclude(k1, k2, k3);
      
      expect(result.hasInclude, isTrue);
      expect(result.newBar.high, equals(110));
      expect(result.newBar.low, equals(103));
    });

    test('Check FX - Top fractal', () {
      final k1 = NewBar(
        symbol: 'AAPL',
        id: 0,
        dt: DateTime(2024, 1, 1),
        freq: Freq.d,
        open: 100,
        close: 102,
        high: 103,
        low: 99,
        vol: 1000,
        elements: [],
      );

      final k2 = NewBar(
        symbol: 'AAPL',
        id: 1,
        dt: DateTime(2024, 1, 2),
        freq: Freq.d,
        open: 102,
        close: 105,
        high: 108,
        low: 101,
        vol: 1200,
        elements: [],
      );

      final k3 = NewBar(
        symbol: 'AAPL',
        id: 2,
        dt: DateTime(2024, 1, 3),
        freq: Freq.d,
        open: 105,
        close: 100,
        high: 106,
        low: 98,
        vol: 800,
        elements: [],
      );

      final fx = checkFx(k1, k2, k3);
      
      expect(fx, isNotNull);
      expect(fx!.mark, equals(Mark.g));
      expect(fx.high, equals(108));
      expect(fx.fx, equals(108));
    });

    test('Check FX - Bottom fractal', () {
      final k1 = NewBar(
        symbol: 'AAPL',
        id: 0,
        dt: DateTime(2024, 1, 1),
        freq: Freq.d,
        open: 105,
        close: 100,
        high: 106,
        low: 98,
        vol: 1000,
        elements: [],
      );

      final k2 = NewBar(
        symbol: 'AAPL',
        id: 1,
        dt: DateTime(2024, 1, 2),
        freq: Freq.d,
        open: 100,
        close: 95,
        high: 101,
        low: 93,
        vol: 1200,
        elements: [],
      );

      final k3 = NewBar(
        symbol: 'AAPL',
        id: 2,
        dt: DateTime(2024, 1, 3),
        freq: Freq.d,
        open: 95,
        close: 98,
        high: 99,
        low: 94,
        vol: 800,
        elements: [],
      );

      final fx = checkFx(k1, k2, k3);
      
      expect(fx, isNotNull);
      expect(fx!.mark, equals(Mark.d));
      expect(fx.low, equals(93));
      expect(fx.fx, equals(93));
    });

    test('ZS - Hub validation', () {
      final fx1 = FX(
        symbol: 'AAPL',
        dt: DateTime(2024, 1, 1),
        mark: Mark.d,
        high: 100,
        low: 95,
        fx: 95,
      );

      final fx2 = FX(
        symbol: 'AAPL',
        dt: DateTime(2024, 1, 5),
        mark: Mark.g,
        high: 110,
        low: 102,
        fx: 110,
      );

      final fx3 = FX(
        symbol: 'AAPL',
        dt: DateTime(2024, 1, 10),
        mark: Mark.d,
        high: 105,
        low: 98,
        fx: 98,
      );

      final bi1 = BI(
        symbol: 'AAPL',
        fxA: fx1,
        fxB: fx2,
        direction: Direction.up,
        fxs: [fx1, fx2],
      );

      final bi2 = BI(
        symbol: 'AAPL',
        fxA: fx2,
        fxB: fx3,
        direction: Direction.down,
        fxs: [fx2, fx3],
      );

      final bi3 = BI(
        symbol: 'AAPL',
        fxA: fx3,
        fxB: fx2,
        direction: Direction.up,
        fxs: [fx3, fx2],
      );

      final zs = ZS(bis: [bi1, bi2, bi3]);
      
      expect(zs.biCount, equals(3));
      expect(zs.zg, equals(105)); // min(110, 110, 110) = 110? No, min of highs
      expect(zs.zd, equals(98)); // max of lows
      expect(zs.isValid, isTrue);
    });

    test('CZSC analysis with sample data', () {
      final bars = _generateSampleKlines();
      final czsc = CZSC(bars: bars);

      print('K线数量: ${czsc.barsRaw.length}');
      print('笔数量: ${czsc.biList.length}');
      print('中枢数量: ${czsc.zsList.length}');

      for (var i = 0; i < czsc.biList.length; i++) {
        final bi = czsc.biList[i];
        print('笔${i + 1}: ${bi.direction} ${bi.sdt} -> ${bi.edt}, high=${bi.high}, low=${bi.low}');
      }

      for (var i = 0; i < czsc.zsList.length; i++) {
        final zs = czsc.zsList[i];
        print('中枢${i + 1}: ${zs.sdt} -> ${zs.edt}, zg=${zs.zg}, zd=${zs.zd}, 笔数=${zs.biCount}');
      }

      expect(czsc.barsRaw.length, equals(bars.length));
    });
  });
}

List<RawBar> _generateSampleKlines() {
  final bars = <RawBar>[];
  var price = 100.0;
  final random = _SimpleRandom(42);

  for (var i = 0; i < 200; i++) {
    final change = (random.nextDouble() - 0.5) * 5;
    final open = price;
    final close = price + change;
    final high = (open > close ? open : close) + random.nextDouble() * 2;
    final low = (open < close ? open : close) - random.nextDouble() * 2;

    bars.add(RawBar(
      symbol: 'AAPL',
      id: i,
      dt: DateTime(2024, 1, 1).add(Duration(days: i)),
      freq: Freq.d,
      open: double.parse(open.toStringAsFixed(2)),
      close: double.parse(close.toStringAsFixed(2)),
      high: double.parse(high.toStringAsFixed(2)),
      low: double.parse(low.toStringAsFixed(2)),
      vol: 1000 + random.nextInt(500),
    ));

    price = close;
  }

  return bars;
}

class _SimpleRandom {
  int _seed;
  _SimpleRandom(this._seed);

  double nextDouble() {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed / 0x7FFFFFFF;
  }

  int nextInt(int max) {
    return (nextDouble() * max).floor();
  }
}
