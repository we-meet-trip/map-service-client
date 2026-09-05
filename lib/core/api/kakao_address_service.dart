import 'api_client.dart';

class KakaoAddressResult {
  final String roadAddress;
  final String jibunAddress;

  const KakaoAddressResult({
    required this.roadAddress,
    required this.jibunAddress,
  });

  /// 표시용 대표 주소 (도로명 우선, 없으면 지번)
  String get displayAddress => roadAddress.isNotEmpty ? roadAddress : jibunAddress;

  factory KakaoAddressResult.fromJson(Map<String, dynamic> json) {
    return KakaoAddressResult(
      roadAddress: json['road_address'] as String? ?? '',
      jibunAddress: json['address'] as String? ?? '',
    );
  }
}

/// 서버가 돌려준 주소 목록을 결과로 바꾼다.
///
/// 통신과 떼어 두어 응답 모양이 바뀌었을 때 통신 없이 확인할 수 있다.
List<KakaoAddressResult> parseAddressSearchResponse(Map<String, dynamic> body) {
  final addresses = body['addresses'] as List<dynamic>? ?? const [];
  return addresses
      .map((a) => KakaoAddressResult.fromJson(a as Map<String, dynamic>))
      .toList();
}

/// 주소 검색.
///
/// 예전에는 앱이 발급처를 직접 불렀다. 그러려면 발급처 키를 설치 파일에
/// 실어야 했고, 파일을 연 사람이면 누구나 그 키를 꺼내 쓸 수 있었다.
/// 지금은 서버를 거치므로 키가 앱에 남지 않는다.
class KakaoAddressService {
  KakaoAddressService._();
  static final KakaoAddressService instance = KakaoAddressService._();

  final _api = ApiClient.instance;

  Future<List<KakaoAddressResult>> search(String query) async {
    final body = await _api.get(
      '/api/v1/places/address',
      query: {'query': query},
    );
    return parseAddressSearchResponse(body);
  }
}
