import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 지도 위 경로의 출처 표기.
///
/// 경로선은 OpenStreetMap 자료로 만든다. 대중교통 노선·시각은 그와 다른
/// 발급처(ODsay)에서 오므로 같은 문구로 덮으면 표기가 틀린 것이 된다.
/// 두 자리가 서로 다른 문구를 쓰도록 무엇을 밝힐지 받아 둔다.
class RouteDataAttribution extends StatelessWidget {
  const RouteDataAttribution({super.key})
      : label = '경로 © OpenStreetMap contributors',
        link = 'https://www.openstreetmap.org/copyright';

  /// 대중교통 노선·시각 출처. 지도 경로선과 발급처가 다르다.
  const RouteDataAttribution.transit({super.key})
      : label = '대중교통 정보 © ODsay',
        link = 'https://lab.odsay.com';

  final String label;
  final String link;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        child: TextButton(
          onPressed: () async {
            var opened = false;
            try {
              opened = await launchUrl(
                Uri.parse(link),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {
              // Keep the current route usable if an external browser is unavailable.
            }
            if (!opened && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('출처 페이지를 열 수 없습니다.')),
              );
            }
          },
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
      );
}
