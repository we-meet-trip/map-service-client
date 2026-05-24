import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupCompleteScreen extends StatelessWidget {
  const SignupCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('가입을 축하합니다!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}