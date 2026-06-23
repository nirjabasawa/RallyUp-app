import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/chat_thread.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/player_details/messages/messages_widgets.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/side_menu_drawer.dart';
import '../../widgets/user_avatar.dart';
import '../player_details/message_page.dart';
import 'group_messages_page.dart';
import 'unread_messages_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  // Lookup cache keyed by uid so we don't refetch the other user every
  // time the threads stream emits a new snapshot.
  final Map<String, AppUser?> _userCache = {};

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AppUser?> _resolveOther(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    final user = await _userService.getUser(uid);
    _userCache[uid] = user;
    return user;
  }

  void _openThread(AppUser other) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MessagePage(otherUser: other),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SideMenuDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Builder(
              builder: (context) {
                return MessagesHeader(
                  showMenuButton: true,
                  onMenuTap: () => Scaffold.of(context).openDrawer(),
                  trailing: const NotificationBellButton(),
                );
              },
            ),
            Expanded(
              child: me == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('Sign in to view your conversations.'),
                      ),
                    )
                  : StreamBuilder<List<ChatThread>>(
                      stream: _chatService.streamThreadsForUser(me.uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final threads = snapshot.data ?? const <ChatThread>[];
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            AppSpacing.lg,
                            AppSpacing.pageHorizontal,
                            AppSpacing.xxl,
                          ),
                          children: [
                            MessageSearchBar(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.md),
                            MessageFilterTabs(
                              onAllTap: () {},
                              onUnreadTap: () {
                                Navigator.of(context).push(
                                  _fadeRoute<void>(const UnreadMessagesPage()),
                                );
                              },
                              onGroupsTap: () {
                                Navigator.of(context).push(
                                  _fadeRoute<void>(const GroupMessagesPage()),
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Recent conversations',
                              style: AppTextStyles.sectionTitle.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (threads.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xxl,
                                ),
                                child: Center(
                                  child: Text(
                                    'No conversations yet',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (final thread in threads)
                                _ThreadTile(
                                  key: ValueKey(thread.id),
                                  thread: thread,
                                  myUid: me.uid,
                                  searchQuery: _searchQuery,
                                  resolveOther: _resolveOther,
                                  onTap: _openThread,
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

/// Per-thread row that resolves the "other" participant lazily through a
/// caller-provided async lookup so the page can cache results across
/// thread-stream emissions. The MessageThreadTile widget is intentionally
/// not used here — it's coupled to the old mock data shape (group avatar
/// stacks, unread badges, online presence) that hasn't been wired up to
/// real data yet. This is a simpler row that uses the shared UserAvatar.
class _ThreadTile extends StatefulWidget {
  final ChatThread thread;
  final String myUid;
  final String searchQuery;
  final Future<AppUser?> Function(String uid) resolveOther;
  final void Function(AppUser other) onTap;

  const _ThreadTile({
    super.key,
    required this.thread,
    required this.myUid,
    required this.searchQuery,
    required this.resolveOther,
    required this.onTap,
  });

  @override
  State<_ThreadTile> createState() => _ThreadTileState();
}

class _ThreadTileState extends State<_ThreadTile> {
  AppUser? _other;
  bool _loading = true;
  String? _resolvedUid;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _ThreadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the underlying thread changes its participants (shouldn't happen
    // for direct chats once created, but guard anyway), re-resolve.
    final otherUid = widget.thread.otherParticipant(widget.myUid);
    if (otherUid != _resolvedUid) _resolve();
  }

  Future<void> _resolve() async {
    final otherUid = widget.thread.otherParticipant(widget.myUid);
    _resolvedUid = otherUid;
    if (otherUid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final user = await widget.resolveOther(otherUid);
    if (!mounted) return;
    setState(() {
      _other = user;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.trim().toLowerCase();
    // Hide threads whose other user doesn't match the search until they
    // resolve — that matches what other messaging apps do (you don't see
    // a half-loaded row in the search list).
    if (query.isNotEmpty) {
      final other = _other;
      if (other == null) return const SizedBox.shrink();
      final preview = (widget.thread.lastMessage ?? '').toLowerCase();
      if (!other.displayName.toLowerCase().contains(query) &&
          !preview.contains(query)) {
        return const SizedBox.shrink();
      }
    }

    final isUnread = widget.thread.isUnreadFor(widget.myUid);
    final borderRadius = BorderRadius.circular(AppSpacing.cardRadius);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _other == null ? null : () => widget.onTap(_other!),
          borderRadius: borderRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: borderRadius,
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
              children: [
                if (_loading)
                  const SizedBox(
                    width: 54,
                    height: 54,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  UserAvatar(
                    size: 54,
                    initials: _other?.initials ?? '?',
                    photoUrl: _other?.photoUrl,
                    avatarId: _other?.avatarId,
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
                              _other?.displayName ??
                                  (_loading ? 'Loading…' : 'Unknown user'),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: isUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            _formatThreadTime(widget.thread.lastMessageAt),
                            style: AppTextStyles.caption.copyWith(
                              color: isUnread
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              widget.thread.lastMessage?.isNotEmpty == true
                                  ? widget.thread.lastMessage!
                                  : 'No messages yet',
                              style: AppTextStyles.body.copyWith(
                                color: isUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUnread) ...[
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

/// Compact thread-time label: clock time today, "Yesterday", short
/// weekday this week, MM/DD otherwise. Deliberately simple — full
/// "smart timestamp" formatting can come with the unread/typing phase.
String _formatThreadTime(DateTime? t) {
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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[t.weekday - 1];
  }
  final mm = t.month.toString().padLeft(2, '0');
  final dd = t.day.toString().padLeft(2, '0');
  return '$mm/$dd';
}
