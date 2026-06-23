import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/chat_thread.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/courts/court_network_image.dart';
import '../../widgets/player_details/messages/messages_widgets.dart';
import '../player_details/group_chat_page.dart';
import 'unread_messages_page.dart';

/// Real "Groups" tab. Streams every open-match group thread the
/// current user is a participant of via
/// `ChatService.streamGroupThreadsForUser`. Static mock data — the
/// old `_threads` list with "SCU Evening Tennis Match" / "Bay
/// Badminton Doubles" / "Weekend Basketball Run" — is gone.
///
/// Direct threads keep their own tab; they're filtered out
/// server-side by `streamGroupThreadsForUser`.
class GroupMessagesPage extends StatelessWidget {
  const GroupMessagesPage({super.key});

  void _openGroupThread(BuildContext context, ChatThread thread) {
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GroupChatPage(threadId: thread.id),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final chatService = ChatService();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const MessagesHeader(title: 'Group Messages', showBackButton: true),
            Expanded(
              child: me == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Sign in to view your group conversations.',
                        ),
                      ),
                    )
                  : StreamBuilder<List<ChatThread>>(
                      stream: chatService.streamGroupThreadsForUser(me.uid),
                      builder: (context, snapshot) {
                        final waitingFirst =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        final threads = snapshot.data ?? const <ChatThread>[];

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            AppSpacing.lg,
                            AppSpacing.pageHorizontal,
                            AppSpacing.xxl,
                          ),
                          children: [
                            const MessageSearchBar(),
                            const SizedBox(height: AppSpacing.md),
                            MessageFilterTabs(
                              selectedFilter: 'Groups',
                              onAllTap: () => Navigator.maybePop(context),
                              onUnreadTap: () {
                                Navigator.of(context).pushReplacement(
                                  _fadeRoute<void>(const UnreadMessagesPage()),
                                );
                              },
                              onGroupsTap: () {},
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Group conversations',
                              style: AppTextStyles.sectionTitle.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (waitingFirst)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxl,
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (threads.isEmpty)
                              const _NoGroupsCard()
                            else
                              for (final thread in threads)
                                _GroupThreadTile(
                                  key: ValueKey(thread.id),
                                  thread: thread,
                                  myUid: me.uid,
                                  onTap: () =>
                                      _openGroupThread(context, thread),
                                ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-row widget for the groups list. Uses the court image as the
/// thread thumbnail and the sport/court snapshot stored on the
/// thread doc for title + status so we don't refetch the open match
/// per card.
class _GroupThreadTile extends StatelessWidget {
  final ChatThread thread;
  final String myUid;
  final VoidCallback onTap;

  const _GroupThreadTile({
    super.key,
    required this.thread,
    required this.myUid,
    required this.onTap,
  });

  String _timeText() {
    final t = thread.lastMessageAt;
    if (t == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(t.year, t.month, t.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) {
      final h = t.hour;
      final m = t.minute.toString().padLeft(2, '0');
      final hour12 = ((h + 11) % 12) + 1;
      final period = h < 12 ? 'AM' : 'PM';
      return '$hour12:$m $period';
    }
    if (diff == 1) return 'Yesterday';
    if (diff < 7) {
      const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return wd[t.weekday - 1];
    }
    final mm = t.month.toString().padLeft(2, '0');
    final dd = t.day.toString().padLeft(2, '0');
    return '$mm/$dd';
  }

  @override
  Widget build(BuildContext context) {
    final unread = thread.isUnreadFor(myUid);
    final preview = (thread.lastMessage?.isNotEmpty == true)
        ? thread.lastMessage!
        : 'No messages yet';
    final title = (thread.title?.isNotEmpty == true)
        ? thread.title!
        : 'Open match group';
    final participantsLabel = thread.participantIds.length == 1
        ? '1 participant'
        : '${thread.participantIds.length} participants';

    final borderRadius = BorderRadius.circular(AppSpacing.cardRadius);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: borderRadius,
              border: Border.all(
                color: unread
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(
                    alpha: unread ? 0.07 : 0.035,
                  ),
                  blurRadius: unread ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 54,
                    height: 54,
                    child: CourtNetworkImage(
                      url: (thread.imageUrl?.isNotEmpty == true)
                          ? thread.imageUrl
                          : null,
                      iconSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: unread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _timeText(),
                            style: AppTextStyles.caption.copyWith(
                              color: unread
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              style: AppTextStyles.body.copyWith(
                                color: unread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.brightGreen,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 15,
                            color: AppColors.brightGreen,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            participantsLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGroupsCard extends StatelessWidget {
  const _NoGroupsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.groups_outlined,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No group conversations yet',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Host or join an open match to start chatting.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PageRouteBuilder<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
  );
}
