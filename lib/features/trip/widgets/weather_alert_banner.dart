import 'package:flutter/material.dart';

import '../../../data/models/weather_alert.dart';

/// 날씨가 바뀐 저장 일정 위에 뜨는 안내 카드.
///
/// 서버는 알림만 걸어 두고 코스를 자동으로 바꾸지 않는다. 무엇을 할지는
/// 사용자가 정한다 — 다시 추천받거나, 알고도 그대로 가거나.
class WeatherAlertBanner extends StatelessWidget {
  const WeatherAlertBanner({
    super.key,
    required this.alert,
    required this.onReplan,
    required this.onDismiss,
    this.busy = false,
  });

  final WeatherAlert alert;
  final VoidCallback onReplan;
  final VoidCallback onDismiss;

  /// 재추천이 도는 중. 두 버튼을 함께 잠근다 — 그 사이에 "이대로 갈게요"가
  /// 눌리면 방금 시작한 재추천의 결과와 어긋난다.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final rain = alert.isRainAppeared;
    // 비가 새로 온다는 알림은 주의를 끌어야 하고, 비가 그쳤다는 알림은
    // 반가운 소식이라 색을 나눈다.
    final bg = rain ? const Color(0xFFEAF2FF) : const Color(0xFFEDF9F0);
    final fg = rain ? const Color(0xFF1D5FCC) : const Color(0xFF1F7A45);
    final icon = rain ? Icons.umbrella_rounded : Icons.wb_sunny_rounded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.headline,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    if (alert.detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        alert.detail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5B6472),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onReplan,
                  style: FilledButton.styleFrom(
                    backgroundColor: fg,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('다시 추천받기',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B6472),
                    side: const BorderSide(color: Color(0xFFD3D9E0)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('이대로 갈게요',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
