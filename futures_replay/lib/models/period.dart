enum Period {
  m1(1, 'M1', '1分钟'),
  m5(5, 'M5', '5分钟'),
  m15(15, 'M15', '15分钟'),
  m30(30, 'M30', '30分钟'),
  h1(60, 'H1', '1小时'),
  h4(240, 'H4', '4小时'),
  d1(1440, 'D1', '日线');

  final int minutes;
  final String code;
  final String label;

  const Period(this.minutes, this.code, this.label);
}
