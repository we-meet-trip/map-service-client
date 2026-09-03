import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'naver_map_adapter.dart';

/// 지도 식별자를 쓸 순서대로 돌려준다.
///
/// 앞의 것이 1순위다. 발급처는 등록해 둔 도메인·패키지와 요청이 맞지 않으면
/// 인증을 거절하는데, 그 판정이 화면을 열기 전까지 드러나지 않아 잘못된 값이
/// 오래 남기 쉽다. 그래서 하나만 들고 있지 않고 순서를 둔다.
///
/// 빈 값과 앞뒤 공백은 걸러 내고, 두 자리에 같은 값이 들어 있으면 한 번만
/// 시도한다 — 같은 값으로 두 번 붙어 봐야 결과가 달라지지 않는다.
@visibleForTesting
List<String> resolveNaverMapClientIds(Map<String, String> env) {
  final ordered = <String>[];
  for (final name in const [
    'NAVER_MAP_CLIENT_ID',
    'NAVER_MAP_CLIENT_ID_FALLBACK',
  ]) {
    final value = (env[name] ?? '').trim();
    if (value.isEmpty || ordered.contains(value)) continue;
    ordered.add(value);
  }
  return ordered;
}

/// 지도 식별자가 몇 번째 것으로 바뀌었는지 세는 값.
///
/// 인증 판정은 지도를 실제로 그릴 때 온다. 그래서 다음 식별자로 다시 붙는
/// 시점에는 이미 그려진 지도가 화면에 있는데, 그 지도는 처음 붙을 때의
/// 식별자로 인증을 끝낸 뒤라 스스로 다시 묻지 않는다 — 값만 바꾸면 화면은
/// 빈 채로 남는다.
///
/// 지도를 띄우는 화면은 이 값을 듣고 있다가 바뀌면 지도를 다시 만든다.
final ValueNotifier<int> naverMapAuthGeneration = ValueNotifier<int>(0);

/// 지도 SDK를 띄운다. 인증이 막히면 다음 식별자로 한 번 더 시도한다.
///
/// 앱 시작 경로에서 부르므로 여기서 기다리는 것은 첫 시도까지다. 인증 실패는
/// 지도를 실제로 그릴 때 뒤늦게 오므로, 그때 다음 식별자로 다시 붙인다. 이미
/// 그려진 지도는 그 화면을 다시 열어야 새 식별자로 인증된다.
Future<void> initNaverMap() async {
  final ids = resolveNaverMapClientIds(dotenv.env);
  if (ids.isEmpty) {
    // 값이 아예 없으면 붙일 것이 없다. 어댑터가 "지도 못 띄움" 상태를 켜도록
    // 빈 값으로 한 번 부른다 — 화면은 그 상태를 보고 대체 표시를 그린다.
    await FlutterNaverMap().init(
      clientId: '',
      onAuthFailed: (e) => debugPrint('NaverMap 인증 실패: $e'),
    );
    return;
  }

  var next = 1;
  Future<void> attempt(int index) {
    return FlutterNaverMap().init(
      clientId: ids[index],
      onAuthFailed: (e) {
        debugPrint('NaverMap 인증 실패(${index + 1}/${ids.length}): $e');
        if (next >= ids.length) return;
        final following = next;
        next += 1;
        // 실패 통지 안에서 다시 붙인다. 여기서 기다리지 않는 이유는 이 콜백이
        // SDK 쪽에서 불려 오기 때문이다 — 붙는 동안 막아 두면 그쪽이 멎는다.
        //
        // 붙고 난 뒤에 세대를 올린다. 올리는 순간 화면이 지도를 다시 만드는데,
        // 그보다 식별자 교체가 늦으면 새 지도도 막힌 값으로 인증을 시도한다.
        attempt(following).whenComplete(() {
          naverMapAuthGeneration.value = following;
        });
      },
    );
  }

  await attempt(0);
}
