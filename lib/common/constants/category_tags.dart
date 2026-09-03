/// 서버가 준 장소 분류를 화면이 쓰는 관심사 이름으로 바꾼다.
///
/// 분류는 출처의 계층 문자열이라 그대로 두면 칩에 "여행 / 관광,명소 /
/// 해수욕장,해변" 같은 긴 줄이 들어간다. 화면은 이미 관심사 이름을 쓰고
/// 있으므로 같은 낱말로 맞춘다.
library;

/// 분류 낱말과 화면 관심사 이름의 대응.
///
/// 열쇠는 출처가 실제로 쓰는 낱말이고, 값은 관심사 목록에 있는 이름이다.
/// 상위 낱말만 있어도 그 아래가 전부 걸리므로(예: 음식점 아래의 한식·간식)
/// 하위 낱말은 상위와 결과가 달라질 때만 따로 둔다.
const Map<String, String> kCategoryTagTable = {
  // 음식점 아래 한식·간식·술집 따위가 모두 여기로 걸린다.
  '음식점': '맛집',
  '카페': '카페',
  '커피전문점': '카페',
  '테마카페': '카페',
  '디저트카페': '카페',

  '해수욕장': '해변',
  '해변': '해변',

  '공원': '공원',
  '도시근린공원': '공원',

  '산': '자연',
  '호수': '자연',

  '테마파크': '테마파크',
  '유원지': '테마파크',

  '박물관': '전시',
  '전시관': '전시',
  '미술관': '전시',

  '서점': '서점',
  '시장': '마켓',

  '문화유적': '역사',
  '유적지': '역사',
  '절': '역사',
  '사찰': '역사',

  '문화시설': '문화',

  '전망대': '사진 명소',
  '온천': '힐링',
};

/// 분류 문자열에서 화면에 쓸 이름을 고른다.
///
/// 계층은 뒤로 갈수록 좁은 뜻이라 뒤에서부터 아는 낱말을 찾는다. 아는
/// 낱말이 하나도 없으면 가장 좁은 낱말을 그대로 보여 준다 — 분류를 아예
/// 지우는 것보다 낫다. 분류가 없으면 칩도 없다.
String? tagForCategory(String? category) {
  final segments = _segmentsOf(category);
  if (segments.isEmpty) return null;

  for (final segment in segments.reversed) {
    for (final word in segment) {
      final tag = kCategoryTagTable[word];
      if (tag != null) return tag;
    }
  }
  return _plainest(segments);
}

/// 아는 낱말이 없을 때 보여 줄 낱말.
///
/// 가장 좁은 칸은 가게 이름인 경우가 있다("호텔" 아래의 "베니키아 호텔").
/// 그런 이름은 위 칸의 낱말을 통째로 품고 있으므로, 품긴 쪽을 찾으면
/// 가게 이름 대신 그 낱말을 쓴다.
String _plainest(List<List<String>> segments) {
  final narrowest = segments.last.last;
  for (final segment in segments.reversed.skip(1)) {
    for (final word in segment) {
      if (word != narrowest && narrowest.contains(word)) return word;
    }
  }
  return narrowest;
}

/// 계층을 낱말 묶음으로 쪼갠다.
///
/// 출처는 계층을 `>` 로 잇고 추천 쪽이 그것을 `/` 로 바꿔 보내므로 둘 다
/// 받는다. 한 칸 안에서 뜻이 여럿이면 쉼표로 이어 붙어 온다.
List<List<String>> _segmentsOf(String? category) {
  if (category == null) return const [];
  final segments = <List<String>>[];
  for (final raw in category.split(RegExp(r'[/>＞]'))) {
    final words = raw
        .split(',')
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isNotEmpty) segments.add(words);
  }
  return segments;
}
