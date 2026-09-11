/// 저장된 일정에 걸린 날씨 변화 알림.
///
/// 서버가 일정을 저장하던 시점의 예보를 기준선으로 갖고 있다가, 주기적으로
/// 다시 받아 실내/야외 판단이 뒤집힐 만큼 달라졌을 때 이 값을 채운다.
/// 알림이 없으면 응답에 필드 자체가 없으므로 null 이다.
class WeatherAlert {
  /// rainAppeared: 비 예보가 새로 생김 — 실내 위주로 다시 짤 만하다.
  /// rainCleared: 비 예보가 사라짐 — 야외로 되돌릴 만하다.
  final String kind;
  final DateTime? date;
  final int? popBefore;
  final int? popAfter;

  const WeatherAlert({
    required this.kind,
    required this.date,
    required this.popBefore,
    required this.popAfter,
  });

  static const rainAppeared = 'rain_appeared';
  static const rainCleared = 'rain_cleared';

  bool get isRainAppeared => kind == rainAppeared;

  /// 배너 제목. 사용자가 무엇을 할지 정할 수 있는 문장으로 쓴다 —
  /// "재계획 필요" 같은 개발 용어는 화면에 내보내지 않는다.
  String get headline =>
      isRainAppeared ? '비 예보로 바뀌었어요' : '비 예보가 사라졌어요';

  /// 근거 한 줄. 날짜와 강수확률 변화를 괄호로 덧붙인다.
  /// 값이 없으면 그 부분만 빠진다 — 억지로 0% 라고 적으면 사실과 달라진다.
  String get detail {
    final parts = <String>[];
    if (date != null) parts.add('${date!.month}월 ${date!.day}일');
    if (popBefore != null && popAfter != null) {
      parts.add('강수확률 $popBefore% → $popAfter%');
    }
    return parts.join(' · ');
  }

  static WeatherAlert? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final kind = json['kind'] as String?;
    if (kind == null) return null;
    return WeatherAlert(
      kind: kind,
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      popBefore: (json['pop_before'] as num?)?.toInt(),
      popAfter: (json['pop_after'] as num?)?.toInt(),
    );
  }
}
