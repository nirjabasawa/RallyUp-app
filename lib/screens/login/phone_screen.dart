import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final phoneController = TextEditingController();
  String? phoneError;
  String? formError;
  bool _busy = false;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  bool _looksLikeE164(String value) {
    // Loose check: starts with '+' and 8-15 digits total.
    return RegExp(r'^\+\d{8,15}$').hasMatch(value);
  }

  Future<void> _sendOtp() async {
    setState(() {
      phoneError = null;
      formError = null;
    });

    final phone = phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => phoneError = 'Mobile number is required');
      return;
    }
    if (!_looksLikeE164(phone)) {
      setState(
        () => phoneError = 'Use international format, e.g. +14085551234',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<AuthService>().sendPhoneOtp(
        phoneNumber: phone,
        onCodeSent: (_) {
          if (!mounted) return;
          setState(() => _busy = false);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: phone)),
          );
        },
        onFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            formError = _readable(e);
          });
        },
        onAutoVerified: (_) {
          if (!mounted) return;
          // Auto-verified on some Android devices — auth state already set.
          setState(() => _busy = false);
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          formError = 'Could not send the code. Please try again.';
        });
      }
    }
  }

  String _readable(FirebaseAuthException e) {
    // Firebase often surfaces backend hints (BILLING_NOT_ENABLED,
    // CAPTCHA_CHECK_FAILED, etc.) inside `e.message` on a generic
    // 'internal-error' code. Check the message text BEFORE falling through.
    final msg = e.message ?? '';
    if (msg.contains('BILLING_NOT_ENABLED')) {
      return 'This phone number is not enabled for SMS verification. '
          'Use a test number added in Firebase Console → Authentication → '
          'Phone, or enable Blaze billing for real SMS.';
    }
    if (msg.contains('CAPTCHA_CHECK_FAILED')) {
      return 'Captcha verification failed. Please try again.';
    }
    if (msg.contains('TOO_SHORT') || msg.contains('TOO_LONG')) {
      return 'That phone number does not look valid.';
    }

    switch (e.code) {
      case 'invalid-phone-number':
      case 'missing-phone-number':
        return 'Enter a valid phone number in international format, '
            'e.g. +14085551234.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      case 'app-not-authorized':
      case 'missing-client-identifier':
      case 'invalid-app-credential':
        return 'This app is not yet configured for phone verification. '
            'Please use email sign-in, or contact support.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled for this project.';
      default:
        // Never surface raw Firebase backend strings to the user.
        return 'Could not send the verification code. Please try again.';
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
                "What's your phone number?",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGray,
                ),
              ),

              const SizedBox(height: 28),

              LoginTextField(
                label: 'Mobile Number *',
                controller: phoneController,
              ),

              if (phoneError != null) ...[
                const SizedBox(height: 6),
                Text(
                  phoneError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              if (formError != null) ...[
                const SizedBox(height: 12),
                Text(
                  formError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],

              const Spacer(),

              Center(
                child: PrimaryButton(
                  text: _busy ? 'Sending…' : 'Continue',
                  width: 180,
                  height: 48,
                  backgroundColor: AppColors.darkGreen.withValues(alpha: 0.75),
                  onPressed: _busy ? () {} : _sendOtp,
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
