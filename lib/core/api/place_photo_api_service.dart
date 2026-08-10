import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// 사진을 올린 사람 표기.
///
/// 사진을 화면에 쓰려면 제공자를 함께 밝혀야 한다. 이름이 없으면 표기로서
/// 의미가 없어 서버가 미리 걸러 보내므로, 여기서는 온 값을 그대로 담는다.
class PlacePhotoAttribution {
  /// 제공자 이름.
  final String displayName;

  /// 제공자 프로필 주소. 없을 수 있다.
  final String? uri;

  const PlacePhotoAttribution({required this.displayName, this.uri});

  factory PlacePhotoAttribution.fromJson(Map<String, dynamic> json) =>
      PlacePhotoAttribution(
        displayName: json['display_name'] as String? ?? '',
        uri: json['uri'] as String?,
      );
}

/// 장소 사진 한 장.
///
/// [photoUri] 는 수명이 짧다. 저장해 두면 화면에 띄울 때쯤 죽은 링크가 되므로,
/// 사진이 필요할 때마다 서버에 다시 물어 받는다.
class PlacePhoto {
  /// 이미지 주소.
  final String photoUri;

  /// 원본 가로/세로 크기. 서버가 못 채우면 비어 있다.
  final int? widthPx;
  final int? heightPx;

  /// 제공자 표기 목록.
  final List<PlacePhotoAttribution> attributions;

  /// 원본 사진을 여는 지도 주소. 없을 수 있다.
  final String? googleMapsUri;

  const PlacePhoto({
    required this.photoUri,
    required this.attributions,
    this.widthPx,
    this.heightPx,
    this.googleMapsUri,
  });

  factory PlacePhoto.fromJson(Map<String, dynamic> json) {
    final raw = json['attributions'];
    return PlacePhoto(
      photoUri: json['photo_uri'] as String? ?? '',
      widthPx: (json['width_px'] as num?)?.toInt(),
      heightPx: (json['height_px'] as num?)?.toInt(),
      attributions: raw is List
          ? raw
              .whereType<Map<String, dynamic>>()
              .map(PlacePhotoAttribution.fromJson)
              .where((a) => a.displayName.isNotEmpty)
              .toList()
          : const [],
      googleMapsUri: json['google_maps_uri'] as String?,
    );
  }
}

/// 장소 사진을 가져오는 통로.
class PlacePhotoApiService {
  PlacePhotoApiService._();

  static final PlacePhotoApiService instance = PlacePhotoApiService._();

  /// 서버 주소는 시작할 때 정해진다. 상수로 잡아 두면 그 시점의 값이
  /// 굳어져, 원격에서 받은 주소가 반영되지 않는다.
  static String get _baseUrl => kApiBaseUrl;

  static const _timeout = Duration(seconds: 15);

  /// 장소 사진을 받는다.
  ///
  /// 좌표를 함께 보내는 이유는 같은 상호가 여러 지역에 있어, 이름만으로는
  /// 다른 동네 지점의 사진이 오기 때문이다.
  ///
  /// 사진이 없거나 조회에 실패하면 빈 목록을 돌려준다 — 사진이 없다고 장소
  /// 상세를 못 그리는 것은 아니다. 주소가 비어 온 항목도 화면에 걸 수 없어
  /// 여기서 버린다.
  Future<List<PlacePhoto>> fetchPhotos(
    String query, {
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/v1/places/photos').replace(
      queryParameters: {
        'query': query,
        'lat': '$latitude',
        'lng': '$longitude',
      },
    );
    try {
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode != 200) return const [];
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final raw = body['photos'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(PlacePhoto.fromJson)
          .where((p) => p.photoUri.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
