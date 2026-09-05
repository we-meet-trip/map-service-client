// 주소 검색이 서버를 거쳐 도는지, 응답을 화면이 쓰는 모양으로 푸는지 본다.
//
// 예전에는 앱이 발급처를 직접 불렀다. 그러려면 발급처 키를 설치 파일에
// 실어야 했고, 파일을 연 사람이면 누구나 그 키를 꺼낼 수 있었다. 다시
// 직접 부르는 쪽으로 돌아가면 그 구멍이 되살아나므로, 어디로 묻는지를
// 여기서 못박아 둔다.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:map_service_client/core/api/kakao_address_service.dart';

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('발급처가 아니라 우리 서버에 묻는다', () async {
    Uri? seen;

    await http.runWithClient(
      () => KakaoAddressService.instance.search('역삼'),
      () => MockClient((request) async {
        seen = request.url;
        return _json({'addresses': [], 'count': 0});
      }),
    );

    expect(seen!.host, isNot(contains('kakao')));
    expect(seen!.path, '/api/v1/places/address');
    expect(seen!.queryParameters['query'], '역삼');
  });

  test('도로명이 있으면 그것을, 없으면 지번을 보여 준다', () {
    final results = parseAddressSearchResponse({
      'addresses': [
        {
          'address': '서울 강남구 역삼동 823',
          'road_address': '서울 강남구 테헤란로 1',
        },
        {'address': '서울 종로구 청운동 1', 'road_address': ''},
      ],
      'count': 2,
    });

    expect(results, hasLength(2));
    expect(results[0].displayAddress, '서울 강남구 테헤란로 1');
    expect(results[1].displayAddress, '서울 종로구 청운동 1');
  });

  test('빈 응답에도 깨지지 않는다', () {
    expect(parseAddressSearchResponse(const {}), isEmpty);
  });
}
