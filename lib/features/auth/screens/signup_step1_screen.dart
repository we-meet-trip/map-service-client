import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignupStep1Screen extends StatelessWidget {
  const SignupStep1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('회원가입 Step1 - 이메일'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/signup/step2'),
                child: const Text('다음'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}