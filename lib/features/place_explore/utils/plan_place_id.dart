/// 일정 방문지 순번으로 만드는 지도 식별자.
///
/// 웹 지도는 위젯으로 만든 핀 그림을 쓰지 못해 식별자 끝의 숫자로 배지를
/// 그린다. 0부터 세는 순번을 붙여야 웹과 앱의 번호가 같아진다.
const _prefix = 'stop_';

String planPlaceId(int index) => '$_prefix$index';

/// 식별자에서 순번을 되찾는다. 우리가 만든 모양이 아니면 null.
int? planIndexOf(String placeId) {
  if (!placeId.startsWith(_prefix)) return null;
  return int.tryParse(placeId.substring(_prefix.length));
}
