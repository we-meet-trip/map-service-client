import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('로그인 페이지입니다.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/signup/step1'),
                child: const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}