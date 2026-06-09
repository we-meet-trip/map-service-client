import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('대화방'),
          const SizedBox(height: 16),
          // TODO: 개발용 임시 버튼 - 배포 전 제거
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            child: const Text('[dev] 로그인 화면으로'),
          ),
        ],
      ),
    );
  }
}
