import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/common/constants/interests.dart';
import 'package:map_service_client/common/constants/category_tags.dart';

/// 장소 분류를 화면이 쓰는 관심사 이름으로 바꾸는 규칙 검증.
///
/// 아래 분류 문자열은 장소 조회가 실제로 돌려준 값과, 그것을 바탕으로
/// 계층을 늘리거나 상호명을 덧붙여 만든 변형이다. 조회 원본은 계층을
/// 꺾쇠로 잇지만 추천을 거치며 빗금으로 바뀌므로 두 모양을 함께 둔다.
void main() {
  group('아는 낱말을 만나면 관심사 이름으로 바꾼다', () {
    test('해수욕장은 해변이 된다', () {
      expect(tagForCategory('여행 / 관광,명소 / 해수욕장,해변'), '해변');
    });

    test('음식점 아래는 얼마나 깊든 맛집이 된다', () {
      expect(tagForCategory('음식점 / 한식'), '맛집');
      expect(tagForCategory('음식점 / 한식 / 해물,생선 / 회'), '맛집');
      expect(tagForCategory('음식점 / 간식 / 제과,베이커리'), '맛집');
    });

    test('가게 이름이 붙어도 위쪽 낱말로 가른다', () {
      expect(tagForCategory('음식점 / 카페 / 커피전문점 / 빽다방'), '카페');
      expect(tagForCategory('음식점 / 카페 / 테마카페 / 디저트카페 / 시나본'), '카페');
    });

    test('나머지 실제 분류도 관심사 이름으로 바뀐다', () {
      expect(tagForCategory('문화,예술 / 문화시설 / 박물관'), '전시');
      expect(tagForCategory('문화,예술 / 문화시설 / 전시관'), '전시');
      expect(tagForCategory('문화,예술 / 도서 / 서점 / 독립서점'), '서점');
      expect(tagForCategory('문화,예술 / 종교 / 불교 / 절,사찰'), '역사');
      expect(tagForCategory('여행 / 관광,명소 / 문화유적 / 유적지'), '역사');
      expect(tagForCategory('가정,생활 / 시장'), '마켓');
      expect(tagForCategory('여행 / 공원 / 도시근린공원'), '공원');
      expect(tagForCategory('여행 / 관광,명소 / 호수'), '자연');
      expect(tagForCategory('여행 / 관광,명소 / 산'), '자연');
      expect(tagForCategory('여행 / 관광,명소 / 테마파크'), '테마파크');
      expect(tagForCategory('여행 / 관광,명소 / 유원지'), '테마파크');
      expect(tagForCategory('여행 / 관광,명소 / 전망대'), '사진 명소');
      expect(tagForCategory('여행 / 관광,명소 / 온천'), '힐링');
    });
  });

  group('아는 낱말이 없을 때', () {
    test('가장 좁은 낱말을 그대로 보여 준다', () {
      expect(tagForCategory('걷기길'), '걷기길');
      expect(tagForCategory('여행 / 관광,명소 / 도보여행 / 해파랑길'), '해파랑길');
      expect(tagForCategory('가정,생활 / 편의점 / 이마트24'), '이마트24');
    });

    test('쉼표로 이어진 낱말은 마지막 것을 쓴다', () {
      expect(tagForCategory('의료,건강 / 병원 / 치과'), '치과');
      expect(tagForCategory('문화,예술 / 미술,공예'), '공예');
    });

    test('가게 이름이 위 낱말을 품고 있으면 위 낱말을 쓴다', () {
      // 숙박은 관심사 목록에 짝이 없어 어느 낱말도 표에 걸리지 않는다.
      // 그때 "베니키아 호텔" 대신 그것이 품고 있는 "호텔" 을 보여 준다.
      expect(tagForCategory('여행 / 숙박 / 호텔 / 베니키아 호텔'), '호텔');
      expect(tagForCategory('교통,수송 / 교통시설 / 주차장 / 공영주차장'), '주차장');
      expect(tagForCategory('여행 / 숙박 / 펜션'), '펜션');
    });
  });

  group('분류가 없거나 비었으면 칩도 없다', () {
    test('없는 분류는 이름도 없다', () {
      expect(tagForCategory(null), isNull);
    });

    test('빈 글자와 구분자만 있는 분류도 이름이 없다', () {
      expect(tagForCategory(''), isNull);
      expect(tagForCategory('   '), isNull);
      expect(tagForCategory(' / / '), isNull);
      expect(tagForCategory(',,'), isNull);
    });
  });

  group('입력 모양이 달라도 같은 결과를 낸다', () {
    test('조회 원본의 꺾쇠 구분자도 받는다', () {
      expect(tagForCategory('여행 > 관광,명소 > 해수욕장,해변'), '해변');
      expect(tagForCategory('음식점 > 카페'), '카페');
    });

    test('앞뒤 빈칸은 무시한다', () {
      expect(tagForCategory('  음식점  /   카페  '), '카페');
    });
  });

  test('바꾼 이름은 모두 화면이 이미 쓰는 관심사다', () {
    final known = kInterestOptions
        .map((option) => option.split(' ').where(_isWord).join(' '))
        .toSet();

    for (final tag in kCategoryTagTable.values) {
      expect(known, contains(tag), reason: '$tag 는 관심사 목록에 없는 이름이다');
    }
  });
}

/// 관심사 이름 뒤에 붙은 그림 문자를 걸러낸다.
bool _isWord(String part) => RegExp(r'[가-힣A-Za-z0-9]').hasMatch(part);
