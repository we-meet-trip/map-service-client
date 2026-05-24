import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupStep3Screen extends StatelessWidget {
  const SignupStep3Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('회원가입 Step3 - 관심사 선택'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/signup/complete'),
                child: const Text('완료'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}