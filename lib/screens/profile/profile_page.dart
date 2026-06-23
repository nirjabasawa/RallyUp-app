import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/logout_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/user_avatar.dart';
import 'account_settings_page.dart';
import 'block_list_page.dart';
import 'feedback_suggestions_page.dart';
import 'legal_page.dart';
import 'notifications_settings_page.dart' as profile_notifications;
import 'profile_settings_screen.dart';
import 'subscription_screen.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<void> _performLogout(BuildContext context) async {
    await performLogout(context);
  }

  Future<void> _performDelete(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.deleteAccount();
      // Success path: AuthProvider has already cleared local state and
      // notified listeners synchronously, so AuthGate is about to repaint
      // to SignupScreen. If we're still mounted, pop any pushed routes
      // back to the gate to keep the stack tidy.
      if (!context.mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      // Auth deletion failed — local state is intact (the user is still
      // signed in with the same profile). Show a readable explanation and
      // let them retry. We never surface raw Firebase backend strings.
      messenger.showSnackBar(SnackBar(content: Text(_readableDeleteError(e))));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Account deletion failed. Please try again.'),
        ),
      );
    }
  }

  String _readableDeleteError(FirebaseAuthException e) {
    switch (e.code) {
      case 'requires-recent-login':
        return 'For security, please log out and log back in, then try '
            'deleting again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'user-not-found':
        // Already gone server-side; behave like success would have.
        return 'Account already removed.';
      default:
        return 'Account deletion failed. Please try again.';
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A4A4A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Log out?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Are you sure you want\nto logout of your\naccount?',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.white),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A4A4A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Delete Account?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontSize: 16,
            ),
          ),
          content: Text(
            'This will permanently delete your\nRallyUp profile and account.\nThis cannot be undone.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.white),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performDelete(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Widget _settingsItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.bodyMedium.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFBFC5CC), height: 1),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 28),
            Text(
              text,
              style: AppTextStyles.sectionTitle.copyWith(
                color: color,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    // After signOut / deleteAccount, AuthProvider clears currentUser and
    // flips status to unauthenticated synchronously. AuthGate (a parent of
    // this page) repaints on the very next frame and replaces the whole
    // MainShell with SignupScreen. Return SizedBox.shrink() — NOT an
    // opaque Scaffold — so if this build happens to render for a frame
    // before AuthGate's rebuild lands, the user sees nothing of it
    // instead of a stuck blank white page.
    if (user == null) {
      return const SizedBox.shrink();
    }
    final headerName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : '';
    final headerInitials = user.initials;
    final headerContact = user.email ?? user.phone ?? '';

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            children: [
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Profile & Preferences',
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const NotificationBellButton(size: 30),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  UserAvatar(
                    size: 82,
                    initials: headerInitials,
                    avatarId: user.avatarId,
                    photoUrl: user.photoUrl,
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerName,
                          style: AppTextStyles.sectionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (headerContact.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            headerContact,
                            style: AppTextStyles.body.copyWith(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (user.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user.location!.displayLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _settingsItem(
                context: context,
                title: 'Player profile settings',
                subtitle: 'Player Details, Sports, Availability',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ProfileSettingsScreen(),
                    ),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Account settings',
                subtitle: 'Sign-in info, Profile visibility',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountSettingsPage(),
                    ),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Subscription',
                subtitle: 'Manage Plans',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Block List',
                subtitle: 'People you have blocked',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockListPage()),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Notifications',
                subtitle: 'Manage notifications',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const profile_notifications.NotificationsPage(),
                    ),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Feedback & Suggestions',
                subtitle: 'Help and support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FeedbackSuggestionsPage(),
                    ),
                  );
                },
              ),
              _settingsItem(
                context: context,
                title: 'Legal',
                subtitle: 'Privacy policy, Terms of Service',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LegalPage()),
                  );
                },
              ),
              const SizedBox(height: 32),
              _actionRow(
                icon: Icons.logout_rounded,
                text: 'Logout',
                color: const Color(0xFFFF4B2B),
                onTap: () => _showLogoutDialog(context),
              ),
              _actionRow(
                icon: Icons.delete_outline_rounded,
                text: 'Delete Account',
                color: AppColors.textSecondary,
                onTap: () => _showDeleteDialog(context),
              ),
              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }
}
