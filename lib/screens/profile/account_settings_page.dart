import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/user_avatar.dart';

/// Account-level controls: read-only sign-in info + a persisted privacy
/// toggle. Profile photo lives in [EditAvatarScreen], ID verification lives
/// in [IdVerificationScreen]. Nothing in this page duplicates those flows.
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    // After signOut / deleteAccount the provider clears currentUser
    // synchronously and AuthGate is about to swap us out — render
    // SizedBox.shrink() so this build is a no-op visually if it lands
    // before AuthGate's repaint (an opaque Scaffold here was showing up
    // as a "blank page" during delete).
    if (user == null) {
      return const SizedBox.shrink();
    }

    final initials = user.initials;
    final signInLabel = user.email ?? user.phone ?? '';
    final signInMethod = user.email != null && user.email!.isNotEmpty
        ? 'Email'
        : (user.phone != null && user.phone!.isNotEmpty ? 'Phone' : 'Account');

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  Text('Account Settings', style: AppTextStyles.pageTitle),
                ],
              ),
              const SizedBox(height: 44),
              Center(
                child: UserAvatar(
                  size: 96,
                  initials: initials,
                  avatarId: user.avatarId,
                  photoUrl: user.photoUrl,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  user.displayName.trim().isEmpty
                      ? 'Your account'
                      : user.displayName.trim(),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              _SectionLabel('Signed in with'),
              const SizedBox(height: 6),
              _ReadOnlyRow(
                icon: user.email != null
                    ? Icons.alternate_email_rounded
                    : Icons.phone_iphone_rounded,
                title: signInMethod,
                value: signInLabel.isEmpty ? 'Account active' : signInLabel,
              ),
              const SizedBox(height: 32),
              _SectionLabel('Privacy'),
              const SizedBox(height: 6),
              _ProfileVisibilityRow(
                value: user.profileVisible,
                onChanged: (next) {
                  context.read<AuthProvider>().updateProfileVisibility(next);
                },
              ),
              if (user.email != null && user.email!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _ResetPasswordRow(email: user.email!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordRow extends StatefulWidget {
  final String email;

  const _ResetPasswordRow({required this.email});

  @override
  State<_ResetPasswordRow> createState() => _ResetPasswordRowState();
}

class _ResetPasswordRowState extends State<_ResetPasswordRow> {
  bool _sending = false;

  Future<void> _sendReset() async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final err = await context.read<AuthProvider>().sendPasswordResetEmail(
      widget.email,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    // Defer the SnackBar so it doesn't insert into the tree on the
    // same frame as the `_sending` rebuild above. Showing it in the
    // same microtask races the rebuild and triggers a framework
    // `_dependents.isEmpty` assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            err ?? 'Reset link sent to ${widget.email}. Check your inbox.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Password',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  "We'll email a secure link to ${widget.email} so you "
                  'can set a new password.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _sending ? null : _sendReset,
            style: TextButton.styleFrom(foregroundColor: AppColors.darkGreen),
            child: Text(_sending ? 'Sending…' : 'Send link'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReadOnlyRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.darkGreen, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileVisibilityRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ProfileVisibilityRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Profile Visibility',
                  style: AppTextStyles.bodyMedium.copyWith(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allow other players to find your profile in nearby '
                  'searches and open matches.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.darkGreen,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
