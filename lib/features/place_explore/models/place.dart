class Place {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  /// 지도에서 고른 장소의 주소. 상세를 따로 받아오지 않아도 팝업이 바로
  /// 주소를 그릴 수 있게 목록 단계에서 함께 들고 온다.
  final String address;

  /// 장소 분류. 분류를 못 정한 장소는 없는 채로 온다.
  final String? category;

  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.category,
  });
}
