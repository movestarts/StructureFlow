enum Period {
  m5(5, '5分钟'),
  m15(15, '15分钟'),
  m30(30, '30分钟'),
  h1(60, '60分钟');

  final int minutes;
  final String label;

  const Period(this.minutes, this.label);
}
