import 'api_client.dart';

/// 장소 검색 결과 한 건.
///
/// 서버가 여러 출처(장소·코스)를 한 형태로 합쳐 주므로 출처마다 채워지는
/// 값이 다르다. 없는 값은 키째 오지 않아 전부 없을 때를 전제로 읽는다.
class PlaceSearchItem {
  /// 추천을 가로질러 같은 장소를 가리키는 식별자("kakao:123").
  final String contentId;
  final String name;
  final String address;

  /// 도로명 주소. 없으면 빈 문자열.
  final String roadAddress;
  final double latitude;
  final double longitude;

  /// 장소 분류(예: "음식점 > 카페"). 없으면 null.
  final String? category;

  /// 출처 서비스의 장소 페이지 링크. 없으면 null.
  final String? placeUrl;

  const PlaceSearchItem({
    required this.contentId,
    required this.name,
    required this.address,
    required this.roadAddress,
    required this.latitude,
    required this.longitude,
    this.category,
    this.placeUrl,
  });

  /// 화면에 보여 줄 주소. 도로명이 있으면 그쪽이 알아보기 쉽다.
  String get displayAddress => roadAddress.isNotEmpty ? roadAddress : address;

  static PlaceSearchItem? tryFromJson(Map<String, dynamic> json) {
    final lat = json['lat'];
    final lng = json['lng'];
    final name = json['name'];
    // 좌표나 이름이 없는 항목은 일정에 넣을 수 없다. 하나 때문에 목록
    // 전체가 열리지 않는 편보다 그 하나를 버리는 편이 낫다.
    if (lat is! num || lng is! num || name is! String || name.isEmpty) {
      return null;
    }
    return PlaceSearchItem(
      contentId: json['content_id'] is String
          ? json['content_id'] as String
          : '',
      name: name,
      address: json['address'] is String ? json['address'] as String : '',
      roadAddress:
          json['road_address'] is String ? json['road_address'] as String : '',
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      category: json['category'] is String ? json['category'] as String : null,
      placeUrl:
          json['place_url'] is String ? json['place_url'] as String : null,
    );
  }
}

/// 장소 검색.
///
/// 발급처를 앱이 직접 부르지 않는다 — 열쇠가 설치 파일에 실리기 때문이다.
/// 서버를 거쳐 물어보고, 검색 범위는 지역으로 좁힌다.
class PlacesApiService {
  PlacesApiService._();
  static final PlacesApiService instance = PlacesApiService._();

  final _api = ApiClient.instance;

  /// 지역 안에서 검색어로 장소를 찾는다.
  ///
  /// province 는 필수다. 없으면 서버가 검색 범위를 정하지 못한다.
  /// size 상한은 서버 계약과 같은 15다.
  Future<List<PlaceSearchItem>> search({
    required String province,
    String? city,
    String? query,
    int size = 15,
  }) async {
    final json = await _api.get('/api/v1/places/search', query: {
      'province': province,
      if (city != null && city.isNotEmpty && city != '선택') 'city': city,
      if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
      'size': '${size.clamp(1, 15)}',
    });
    final items = json['places'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(PlaceSearchItem.tryFromJson)
        .whereType<PlaceSearchItem>()
        .toList();
  }
}
