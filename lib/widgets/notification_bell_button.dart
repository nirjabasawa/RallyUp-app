import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../screens/notifications_page.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

/// Bell icon with an optional small unread dot. Used as the right-side
/// header action on screens that have it (Messages tab, etc.).
///
/// Behavior:
///   * Reads `currentUser` from [AuthProvider].
///   * Subscribes to `NotificationService.streamUnreadCount`.
///   * Shows a small green dot in the top-right corner of the bell
///     whenever the unread count is > 0. We deliberately don't render
///     a count number for now — true unread tracking is binary at
///     this stage and a number would imply we're counting per-thread,
///     which we aren't.
///   * Tapping the icon opens [NotificationsPage] with the same fade
///     transition the rest of the app uses.
class NotificationBellButton extends StatelessWidget {
  /// Icon size. Matches the size most pages used for their previous
  /// compose / bell IconButton so swap-in callers don't lose visual
  /// rhythm.
  final double size;
  final Color color;

  const NotificationBellButton({
    super.key,
    this.size = 28,
    this.color = AppColors.textPrimary,
  });

  void _openNotifications(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NotificationsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return GestureDetector(
      onTap: () => _openNotifications(context),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, size: size, color: color),
          if (me != null)
            // Only subscribe to the unread stream when a user is
            // signed in. When signed out we still show the bell (a
            // pushed route that's about to be popped might render
            // briefly with `me == null`) but we don't waste a
            // Firestore listener on a null uid.
            Positioned(
              right: -2,
              top: -1,
              child: StreamBuilder<int>(
                stream: NotificationService().streamUnreadCount(me.uid),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.brightGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
