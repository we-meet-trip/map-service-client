/// 여행 테마 — 화면 표기와 서버로 보내는 코드값의 대응.
///
/// 여행 계획 단계에서 고르는 것과 **같은 8종**이다. 회원가입에서도 같은
/// 값을 고르게 해, 저장해 둔 취향을 일정 추천에 그대로 쓸 수 있게 한다.
/// 종류를 늘리거나 바꾸지 않는다.
const Map<String, String> kTripThemes = {
  'food': '맛집 탐방',
  'photo': '사진 명소',
  'nature': '자연/풍경',
  'cafe': '카페 투어',
  'history': '역사/문화',
  'activity': '액티비티',
  'shopping': '쇼핑',
  'night': '야경',
};

/// 칩 목록에 쓰는 화면 표기.
final List<String> kTripThemeLabels = kTripThemes.values.toList();

/// 화면 표기 목록을 서버로 보낼 코드값으로 바꾼다.
///
/// 대응을 못 찾은 표기는 버린다 — 서버가 모르는 값을 보내면 추천 조건이
/// 조용히 어긋난다.
List<String> themeIdsFromLabels(List<String> labels) {
  return labels
      .map((label) => kTripThemes.entries
          .where((e) => e.value == label)
          .map((e) => e.key)
          .firstOrNull)
      .whereType<String>()
      .toList();
}

/// 코드값 목록을 화면 표기로 되돌린다. 저장된 취향을 다시 그릴 때 쓴다.
List<String> themeLabelsFromIds(List<String> ids) {
  return ids.map((id) => kTripThemes[id]).whereType<String>().toList();
}
