import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 방 번호를 알아낼 수 없을 때 대신 보여 주는 화면.
///
/// 주소에 숫자가 아닌 것이 들어왔을 때 도달한다. 여기서 그냥 죽게 두면 링크를
/// 잘못 눌렀을 뿐인데 앱이 통째로 꺼진 것처럼 보인다.
class ChatRoomMissingScreen extends StatelessWidget {
  const ChatRoomMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                const Text(
                  '채팅방을 찾을 수 없어요',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1C1C28),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '주소가 올바르지 않아요. 대화방 목록에서 다시 열어 주세요.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF8F8E90)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => context.go('/chat'),
                  child: const Text('대화방 목록으로'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
