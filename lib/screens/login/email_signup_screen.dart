import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';

class EmailSignupScreen extends StatefulWidget {
  const EmailSignupScreen({super.key});

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _busy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _formError = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      return;
    }
    if (confirm != password) {
      setState(() => _confirmError = 'Passwords do not match');
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<AuthService>().signUpWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) return;
      // AuthProvider will detect the auth user and switch to needsOnboarding.
      // Pop back to root so AuthGate renders the onboarding flow.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _formError = _readableError(e);
      });
    } catch (e) {
      setState(() => _formError = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readableError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists for this email. Try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled in Firebase.';
      default:
        return e.message ?? 'Sign-up failed.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 54),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.chevron_left,
                  color: AppColors.darkGreen,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sign up with email',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 28),
              LoginTextField(label: 'Email *', controller: emailController),
              if (_emailError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _emailError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              LoginTextField(
                label: 'Password *',
                controller: passwordController,
                obscureText: true,
              ),
              if (_passwordError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _passwordError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              LoginTextField(
                label: 'Confirm Password *',
                controller: confirmController,
                obscureText: true,
              ),
              if (_confirmError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _confirmError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              if (_formError != null) ...[
                const SizedBox(height: 18),
                Text(
                  _formError!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
              const SizedBox(height: 60),
              Center(
                child: PrimaryButton(
                  text: _busy ? 'Creating account…' : 'Create Account',
                  width: 220,
                  height: 50,
                  backgroundColor: AppColors.darkGreen.withValues(alpha: 0.75),
                  onPressed: _busy ? () {} : _submit,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
