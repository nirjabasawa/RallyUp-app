import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import 'login/name_screen.dart';
import 'login/signup_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.loading:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const SignupScreen();
      case AuthStatus.needsOnboarding:
        return const NameScreen();
      case AuthStatus.authenticated:
        return MainShell(key: MainShell.globalKey);
    }
  }
}
