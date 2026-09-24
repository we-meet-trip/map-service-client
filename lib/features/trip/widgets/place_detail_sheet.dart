import 'package:flutter/material.dart';

import '../../place_explore/models/place_detail.dart';
import '../../place_explore/widgets/place_bottom_sheet.dart';

/// 일정에 담긴 장소의 상세를 아래에서 올라오는 시트로 보여 준다.
///
/// 화면은 장소 탐색과 같은 시트를 쓴다. 예전에는 같은 모양을 두 벌 따로
/// 그렸는데, 한쪽에만 손이 가면서 이쪽에서만 사진 자리가 사라졌다. 같은
/// 장소를 어느 화면에서 열든 담기는 정보가 같아야 한다.
///
/// 다른 점은 하나뿐이다. 이 자리는 이미 짜인 일정을 들여다보는 곳이라 경로에
/// 담는 동작이 없다. 그래서 담기 단추를 넘기지 않으며, 시트도 목록 위에서
/// 바로 읽히도록 더 높이 연다.
///
/// 사진은 [latitude]·[longitude] 가 함께 올 때만 받아 온다. 이름만으로 찾으면
/// 같은 상호의 다른 동네 지점 사진이 오기 때문이다.
Future<void> showPlaceDetailSheet(
  BuildContext context, {
  required String name,
  required String address,
  String? category,
  double? latitude,
  double? longitude,
  bool showAiSummary = true,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => PlaceBottomSheet(
      // 일정 화면은 장소에 식별자를 붙여 두지 않는다. 시트가 식별자를 쓰는
      // 곳은 경로에 담고 빼는 동작뿐인데 여기에는 그 동작이 없다.
      detail: PlaceDetail(
        id: '',
        name: name,
        address: address,
        category: category,
      ),
      latitude: latitude,
      longitude: longitude,
      initialChildSize: 0.72,
      showAiSummary: showAiSummary,
    ),
  );
}
