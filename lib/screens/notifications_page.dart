import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/invite_service.dart';
import '../services/notification_service.dart';
import '../services/open_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../widgets/main_bottom_nav.dart';
import 'booking_confirmed_page.dart';
import 'main_shell_nav.dart';
import 'player_details/match_details_page.dart';
import 'player_details/received_invites_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final BookingService _bookingService = BookingService();
  final OpenMatchService _openMatchService = OpenMatchService();
  final InviteService _inviteService = InviteService();

  void _onBottomNavTap(int index) {
    switchToMainShellTab(context, index);
  }

  Future<void> _onTapNotification(AppNotification n) async {
    if (!n.isRead) {
      // Fire-and-forget; the stream snapshot will reflect the change
      // before the route push lands. Failure is non-fatal.
      _notificationService.markAsRead(n.id).catchError((_) {});
    }
    if (!mounted) return;

    switch (n.targetType) {
      case AppNotification.targetBooking:
        final id = n.targetId;
        if (id == null || id.isEmpty) return;
        final booking = await _bookingService.getBooking(id);
        if (!mounted || booking == null) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => BookingConfirmedPage(booking: booking),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        break;
      case AppNotification.targetInvite:
        // Pending invite → invitee opens ReceivedInvitesPage to
        // act on it. Accepted/declined/cancelled → the underlying
        // match is the natural destination (host got the
        // acceptance notice; everyone else just sees a status
        // change). Falls back to ReceivedInvitesPage if the
        // invite was deleted or the match no longer exists, so
        // the tap is never a dead end.
        final id = n.targetId;
        if (id == null || id.isEmpty) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => const ReceivedInvitesPage(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          break;
        }
        final invite = await _inviteService.getInvite(id);
        if (!mounted) return;
        if (invite == null || invite.isPending) {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, _, _) => const ReceivedInvitesPage(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          break;
        }
        final match = await _openMatchService.getOpenMatch(invite.matchId);
        if (!mounted) return;
        if (match == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This match is no longer available.')),
          );
          break;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => MatchDetailsPage(match: match),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        break;
      case AppNotification.targetMatch:
        final id = n.targetId;
        if (id == null || id.isEmpty) return;
        final match = await _openMatchService.getOpenMatch(id);
        if (!mounted) return;
        if (match == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This match is no longer available.')),
          );
          return;
        }
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, _, _) => MatchDetailsPage(match: match),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
        break;
      default:
        // System-class notifications stay on the list.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                18,
                AppSpacing.pageHorizontal,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Notifications',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (me != null)
                    TextButton(
                      onPressed: () => _notificationService
                          .markAllAsRead(me.uid)
                          .catchError((_) {}),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Mark all read',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: me == null
                  ? const _EmptyState(
                      title: 'Sign in to see notifications',
                      subtitle:
                          'Booking updates, invites, and match activity '
                          'will appear here.',
                    )
                  : StreamBuilder<List<AppNotification>>(
                      stream: _notificationService.streamNotificationsForUser(
                        me.uid,
                      ),
                      builder: (context, snapshot) {
                        final waitingFirst =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        if (waitingFirst) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final items =
                            snapshot.data ?? const <AppNotification>[];
                        if (items.isEmpty) {
                          return const _EmptyState(
                            title: 'No notifications yet',
                            subtitle:
                                'Booking updates, invites, and match '
                                'activity will appear here.',
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            8,
                            AppSpacing.pageHorizontal,
                            24,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final n = items[index];
                            return _NotificationTile(
                              notification: n,
                              onTap: () => _onTapNotification(n),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({required this.notification, required this.onTap});

  IconData _iconFor(String type) {
    switch (type) {
      case AppNotification.typeBookingConfirmed:
        return Icons.event_available_rounded;
      case AppNotification.typeBookingCancelled:
        return Icons.event_busy_rounded;
      case AppNotification.typeInviteReceived:
        return Icons.mail_outline_rounded;
      case AppNotification.typeInviteAccepted:
        return Icons.mark_email_read_outlined;
      case AppNotification.typeInviteDeclined:
        return Icons.mail_outlined;
      case AppNotification.typeOpenMatchCreated:
        return Icons.sports_score_rounded;
      case AppNotification.typeMatchJoined:
        return Icons.groups_rounded;
      case AppNotification.typeMatchLeft:
        return Icons.person_remove_alt_1_rounded;
      case AppNotification.typeOpenMatchCancelled:
        return Icons.event_busy_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  String _relativeTime(DateTime? t) {
    if (t == null) return 'Just now';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('MMM d').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(
                  alpha: isUnread ? 0.07 : 0.035,
                ),
                blurRadius: isUnread ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _iconFor(notification.type),
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 15,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.brightGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: isUnread
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isUnread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
