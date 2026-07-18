import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    final road = json['road_address'] as Map<String, dynamic>?;
    return KakaoAddressResult(
      roadAddress: road?['address_name'] as String? ?? '',
      jibunAddress: json['address_name'] as String? ?? '',
    );
  }
}

class KakaoAddressService {
  KakaoAddressService._();
  static final KakaoAddressService instance = KakaoAddressService._();

  static const _baseUrl = 'https://dapi.kakao.com/v2/local/search/address.json';

  Future<List<KakaoAddressResult>> search(String query) async {
    final apiKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('KAKAO_REST_API_KEY가 설정되지 않았습니다.');
    }
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {'query': query});
    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $apiKey'},
    );

    if (response.statusCode != 200) {
      throw Exception('주소 검색에 실패했습니다. (${response.statusCode})');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final documents = body['documents'] as List<dynamic>;
    return documents
        .map((d) => KakaoAddressResult.fromJson(d as Map<String, dynamic>))
        .toList();
  }
}
