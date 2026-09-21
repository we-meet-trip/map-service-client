import 'package:flutter_test/flutter_test.dart';
import 'package:map_service_client/data/local/permission_notice_store.dart';

/// 기기 저장소가 없어도 첫 화면을 지나갈 수 있어야 한다.
///
/// 상자가 깨져 열리지 않으면 이 저장소는 값을 들지 못한 채로 남는다. 그때
/// 확인 버튼이 상태를 못 바꾸면 관문이 모든 화면을 권한 고지 화면으로 되돌려
/// 앱에서 빠져나올 수 없게 된다. 저장이 안 되는 것과 앱을 쓸 수 없는 것
/// 중에는 앞쪽이 낫다.
void main() {
  test('상자가 없어도 확인이 그 실행 동안 남는다', () async {
    // init 을 부르지 않은 상태가 곧 상자를 들지 못한 상태다.
    expect(PermissionNoticeStore.instance.confirmed, isFalse);

    await PermissionNoticeStore.instance.confirm();
    expect(PermissionNoticeStore.instance.confirmed, isTrue);
  });
}
