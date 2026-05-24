import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupStep2Screen extends StatelessWidget {
  const SignupStep2Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('회원가입 Step2 - 프로필 정보'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/signup/step3'),
                child: const Text('다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}