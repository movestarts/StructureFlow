/// 缠论枚举类型定义
library;

/// 分型标记
enum Mark {
  /// 底分型
  d('底分型'),
  
  /// 顶分型
  g('顶分型');

  final String label;
  const Mark(this.label);

  @override
  String toString() => label;
}

/// 方向
enum Direction {
  /// 向上
  up('向上'),
  
  /// 向下
  down('向下');

  final String label;
  const Direction(this.label);

  @override
  String toString() => label;
}

/// K线周期
enum Freq {
  tick('Tick'),
  f1('1分钟'),
  f2('2分钟'),
  f3('3分钟'),
  f4('4分钟'),
  f5('5分钟'),
  f6('6分钟'),
  f10('10分钟'),
  f12('12分钟'),
  f15('15分钟'),
  f20('20分钟'),
  f30('30分钟'),
  f60('60分钟'),
  f120('120分钟'),
  d('日线'),
  w('周线'),
  m('月线'),
  s('季线'),
  y('年线');

  final String label;
  const Freq(this.label);

  @override
  String toString() => label;
}

/// 操作类型
enum Operate {
  /// 持多
  hl('持多'),
  
  /// 持空
  hs('持空'),
  
  /// 持币
  ho('持币'),
  
  /// 开多
  lo('开多'),
  
  /// 平多
  le('平多'),
  
  /// 开空
  so('开空'),
  
  /// 平空
  se('平空');

  final String label;
  const Operate(this.label);

  @override
  String toString() => label;
}
