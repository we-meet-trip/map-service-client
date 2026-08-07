// 남은 날 계산. 홈 카드와 저장 목록이 같은 값을 써야 한다.

/// 오늘부터 [date] 까지 남은 날 수. 시각은 버리고 날짜만 센다 —
/// 같은 날 오전·오후에 열었다고 값이 달라지면 안 된다.
int daysUntil(DateTime date, {DateTime? now}) =>
    _dateOnly(date).difference(_dateOnly(now ?? DateTime.now())).inDays;

/// 남은 날 수를 배지 문구로. 당일과 지난 날짜는 모두 'D-DAY'.
String dDayLabel(DateTime date, {DateTime? now}) {
  final days = daysUntil(date, now: now);
  return days <= 0 ? 'D-DAY' : 'D-$days';
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
