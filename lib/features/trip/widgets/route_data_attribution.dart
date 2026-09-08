import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RouteDataAttribution extends StatelessWidget {
  const RouteDataAttribution({super.key});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        child: TextButton(
          onPressed: () async {
            var opened = false;
            try {
              opened = await launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
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
          child: const Text('경로 © OpenStreetMap contributors',
              style: TextStyle(fontSize: 12)),
        ),
      );
}
