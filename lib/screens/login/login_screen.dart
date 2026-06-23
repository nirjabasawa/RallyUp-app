import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/login_text_field.dart';
import '../../widgets/primary_button.dart';
import 'phone_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? emailError;
  String? passwordError;
  String? formError;
  bool _busy = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(value);
  }

  Future<void> _login() async {
    setState(() {
      emailError = null;
      passwordError = null;
      formError = null;
    });

    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => emailError = 'Enter a valid email');
      return;
    }
    if (password.isEmpty) {
      setState(() => passwordError = 'Password cannot be empty');
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<AuthService>().signInWithEmail(
        email: email,
        password: password,
      );
      if (!mounted) return;
      // AuthProvider's listener will detect the auth user and the gate
      // will route to MainShell (or onboarding if no profile yet).
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() => formError = _readable(e));
    } catch (_) {
      setState(() => formError = 'Login failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readable(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return e.message ?? 'Login failed.';
    }
  }

  void _goToPhoneLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhoneScreen()),
    );
  }

  /// Forgot-password flow. Prefills the email from the login form
  /// if the user already typed one, lets them confirm/edit it, then
  /// calls `AuthProvider.sendPasswordResetEmail`. We show a generic
  /// "if an account exists" message regardless of the actual result
  /// so we don't leak which emails are registered.
  Future<void> _openForgotPasswordDialog() async {
    final controller = TextEditingController(text: emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? localError;
        bool sending = false;
        return StatefulBuilder(
          builder: (statefulContext, setLocal) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Reset password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "We'll email you a secure link to set a new "
                    'password.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: localError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(dialogContext, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sending
                      ? null
                      : () async {
                          final entered = controller.text.trim();
                          if (entered.isEmpty || !_isValidEmail(entered)) {
                            setLocal(() => localError = 'Enter a valid email');
                            return;
                          }
                          setLocal(() {
                            sending = true;
                            localError = null;
                          });
                          final err = await context
                              .read<AuthProvider>()
                              .sendPasswordResetEmail(entered);
                          if (!statefulContext.mounted) return;
                          if (err != null) {
                            setLocal(() {
                              sending = false;
                              localError = err;
                            });
                            return;
                          }
                          Navigator.pop(dialogContext, entered);
                        },
                  child: const Text('Send link'),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    // Capture the messenger while the BuildContext is still valid.
    // Then defer EVERYTHING to the next frame — the controller
    // dispose, the mounted recheck, and the SnackBar insertion.
    // Calling `controller.dispose()` synchronously immediately after
    // `await showDialog` fires while the dialog overlay route is
    // still tearing down; descendant elements that depended on the
    // dialog's InheritedWidgets haven't been deactivated yet, which
    // is what the framework `_dependents.isEmpty` assertion is
    // catching.
    final messenger = ScaffoldMessenger.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
      if (email == null) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'If an account exists for $email, a reset link is on its way.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 64),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 58),

                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(
                    Icons.chevron_left,
                    color: AppColors.darkGreen,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkGray,
                  ),
                ),

                const SizedBox(height: 34),

                LoginTextField(label: 'Email', controller: emailController),

                if (emailError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    emailError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],

                const SizedBox(height: 28),

                LoginTextField(
                  label: 'Password',
                  controller: passwordController,
                  obscureText: true,
                ),

                if (passwordError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    passwordError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],

                if (formError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    formError!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],

                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _openForgotPasswordDialog,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: AppColors.darkGreen,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                Center(
                  child: PrimaryButton(
                    text: _busy ? 'Logging in…' : 'Login',
                    width: 230,
                    height: 56,
                    backgroundColor: AppColors.darkGreen.withValues(
                      alpha: 0.75,
                    ),
                    onPressed: _busy ? () {} : _login,
                  ),
                ),

                const SizedBox(height: 60),

                Row(
                  children: const [
                    Expanded(
                      child: Divider(color: AppColors.mediumGray, thickness: 2),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: AppColors.grayText,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: AppColors.mediumGray, thickness: 2),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                PrimaryButton(
                  text: 'Continue with Phone',
                  backgroundColor: AppColors.brightGreen,
                  onPressed: _goToPhoneLogin,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
