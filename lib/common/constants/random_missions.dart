/// 랜덤 여행에서 뽑는 미션.
///
/// [query] 는 미션 장소를 찾을 때 검색창에 미리 채우는 낱말이다. 없으면 따로
/// 찾을 장소가 없는 미션이다.
///
/// [universal] 은 어느 지역에서든 할 수 있는 미션이다. 섬 지역이나 검색 결과가
/// 없을 때는 이 미션들 가운데서만 다시 뽑는다.
class RandomMission {
  const RandomMission({
    required this.id,
    required this.title,
    this.query,
    this.universal = false,
  });

  final String id;
  final String title;
  final String? query;
  final bool universal;
}

const List<RandomMission> kRandomMissions = [
  RandomMission(id: 'museum', title: '박물관을 찾아 탐방하세요!', query: '박물관'),
  RandomMission(id: 'gallery', title: '미술관·갤러리에서 마음에 드는 작품 하나 찾기', query: '미술관'),
  RandomMission(id: 'photo_spot', title: '유명한 사진 스팟을 찾아주세요!', query: '포토존'),
  RandomMission(id: 'observatory', title: '전망대에 올라 동네를 한눈에', query: '전망대'),
  RandomMission(id: 'night_view', title: '해 질 녘 야경 명소에서 한 장', query: '야경'),
  RandomMission(id: 'market', title: '전통시장에서 지역 간식 맛보기', query: '전통시장'),
  RandomMission(id: 'local_food', title: '현지인 단골 맛집에서 한 끼', query: '맛집', universal: true),
  RandomMission(id: 'regional_dish', title: '그 지역 향토음식 먹어보기', query: '향토음식'),
  RandomMission(id: 'bakery', title: '동네 빵집 대표 빵 사기', query: '빵집', universal: true),
  RandomMission(id: 'cafe', title: '처음 가 보는 카페에서 쉬어가기', query: '카페', universal: true),
  RandomMission(id: 'park', title: '공원에서 30분 산책', query: '공원', universal: true),
  RandomMission(id: 'temple', title: '오래된 절이나 고택 찾아가기', query: '사찰'),
  RandomMission(id: 'heritage', title: '문화유적 한 곳 탐방', query: '유적지'),
  RandomMission(id: 'memorial', title: '기념관·역사관에서 지역 이야기 알기', query: '기념관'),
  RandomMission(id: 'beach', title: '바다나 해변 보러 가기', query: '해수욕장'),
  RandomMission(id: 'lake', title: '호수나 계곡 물가에서 쉬기', query: '호수'),
  RandomMission(id: 'arboretum', title: '수목원·식물원 걷기', query: '수목원'),
  RandomMission(id: 'trail', title: '걷기길 한 구간 걸어보기', query: '둘레길'),
  RandomMission(id: 'workshop', title: '공방에서 이색 체험 하나', query: '공방 체험'),
  RandomMission(id: 'bookstore', title: '동네 서점에서 책 한 권 고르기', query: '서점'),
  RandomMission(id: 'sign_photo', title: '지역 이름이 적힌 표지판과 인증샷', universal: true),
  RandomMission(id: 'specialty', title: '그 지역 특산물 하나 사 오기', query: '특산물'),
  RandomMission(id: 'hot_spring', title: '온천이나 족욕으로 쉬어가기', query: '온천'),
];

/// 배로만 닿는 지역. 대상이 있는지 장담할 수 없어 어디서나 되는 미션만 뽑는다.
const Set<String> kIslandCities = {'옹진군', '울릉군'};
