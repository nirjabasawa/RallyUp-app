import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otpController = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code we sent you');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      await context.read<AuthService>().verifyOtp(code);
      if (!mounted) return;
      // AuthProvider's auth-state listener will switch the gate to
      // needsOnboarding (new user) or authenticated (returning user).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _readable(e));
    } catch (_) {
      setState(() => _error = 'Verification failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(FirebaseAuthException e) {
    final msg = e.message ?? '';
    if (msg.contains('BILLING_NOT_ENABLED')) {
      return 'This phone number is not enabled for SMS verification. '
          'Use a test number added in Firebase Console.';
    }
    switch (e.code) {
      case 'invalid-verification-code':
        return 'That code is incorrect. Please try again.';
      case 'invalid-verification-id':
        return 'Verification session was lost. Go back and request a new code.';
      case 'session-expired':
        return 'The code expired. Go back and request a new one.';
      case 'no-verification-in-progress':
        return 'Verification expired. Go back and request a new code.';
      case 'credential-already-in-use':
        return 'This phone number is already linked to another account.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
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
                'Enter the verification code',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGray,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sent to ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 14, color: AppColors.grayText),
              ),
              const SizedBox(height: 28),
              LoginTextField(
                label: '6-digit code *',
                controller: otpController,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const Spacer(),
              Center(
                child: PrimaryButton(
                  text: _busy ? 'Verifying…' : 'Verify',
                  width: 180,
                  height: 48,
                  backgroundColor: AppColors.darkGreen.withValues(alpha: 0.75),
                  onPressed: _busy ? () {} : _verify,
                ),
              ),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }
}
