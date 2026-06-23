import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/user_avatar.dart';

/// Direct 1-to-1 chat. Thread id is deterministic, so the page
/// resolves it in one read and streams messages live. Sends go
/// through `ChatService.sendMessage`, which bumps the parent
/// thread's preview atomically.
class MessagePage extends StatefulWidget {
  final AppUser otherUser;

  const MessagePage({super.key, required this.otherUser});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _threadId;
  String? _initError;
  bool _sending = false;

  /// Last incoming message we've already marked read — gate so the
  /// per-snapshot `markThreadRead` only fires for new messages.
  String? _lastMarkedMessageId;

  @override
  void initState() {
    super.initState();
    _ensureThread();
  }

  Future<void> _ensureThread() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) {
      setState(() => _initError = 'You must be signed in to send messages.');
      return;
    }
    try {
      final id = await _chatService.createOrGetDirectThread(
        currentUid: me.uid,
        otherUid: widget.otherUser.uid,
      );
      if (!mounted) return;
      setState(() => _threadId = id);
      // Mark read on open so any pre-existing unread message clears
      // immediately. Fresh messages are handled by `_maybeMarkRead`.
      _chatService.markThreadRead(threadId: id, uid: me.uid).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = 'Could not open this conversation.');
    }
  }

  /// Bumps the read timestamp when a new message from the other
  /// user lands. Scheduled post-frame so we don't mutate Firestore
  /// inside a build pass.
  void _maybeMarkRead(List<ChatMessage> messages, String myUid) {
    final id = _threadId;
    if (id == null || messages.isEmpty) return;
    final latest = messages.last;
    if (latest.senderUid == myUid) return;
    if (latest.id == _lastMarkedMessageId) return;
    _lastMarkedMessageId = latest.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatService.markThreadRead(threadId: id, uid: myUid).catchError((_) {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _threadId == null || _sending) return;
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) return;

    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        threadId: _threadId!,
        senderUid: me.uid,
        text: text,
      );
      if (!mounted) return;
      _textController.clear();
      // Jump to the latest message on the next frame. The list is
      // reverse: true, so the newest entry sits at scroll offset 0.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final myUid = me?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFA),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(otherUser: widget.otherUser),
            if (_initError != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      _initError!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              )
            else if (_threadId == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _chatService.streamMessages(_threadId!),
                  builder: (context, snapshot) {
                    final messages = snapshot.data;
                    if (messages == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    // Mark-as-read side effect: deferred to a post-frame
                    // callback inside `_maybeMarkRead`, idempotent via
                    // `_lastMarkedMessageId`. Safe even when `messages`
                    // is empty (the helper short-circuits).
                    if (myUid != null) {
                      _maybeMarkRead(messages, myUid);
                    }
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Start the conversation',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    // Render newest-at-bottom by flipping the list and the
                    // ListView together. `reverse: true` keeps the latest
                    // message anchored to the bottom of the viewport and
                    // auto-sticks the input bar to the most recent reply.
                    final reversed = messages.reversed.toList(growable: false);
                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      itemCount: reversed.length,
                      itemBuilder: (context, i) {
                        final msg = reversed[i];
                        final isMine = myUid != null && msg.senderUid == myUid;
                        return _ChatBubble(
                          text: msg.text,
                          time: _formatClockTime(context, msg.sentAt),
                          isMine: isMine,
                          otherUser: widget.otherUser,
                        );
                      },
                    );
                  },
                ),
              ),
            _MessageInput(
              controller: _textController,
              sending: _sending,
              enabled: _threadId != null && _initError == null,
              onSend: _send,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

String _formatClockTime(BuildContext context, DateTime t) {
  final tod = TimeOfDay.fromDateTime(t);
  return MaterialLocalizations.of(context).formatTimeOfDay(tod);
}

/// Header bar showing the other user's real avatar and name, plus the
/// system back button. No phone-call / kebab actions — they were
/// purely decorative on the static mock.
class _ChatHeader extends StatelessWidget {
  final AppUser otherUser;

  const _ChatHeader({required this.otherUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.18),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.textPrimary,
            tooltip: 'Back',
          ),
          UserAvatar(
            size: 42,
            initials: otherUser.initials,
            photoUrl: otherUser.photoUrl,
            avatarId: otherUser.avatarId,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              otherUser.displayName,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMine;
  final AppUser otherUser;

  const _ChatBubble({
    required this.text,
    required this.time,
    required this.isMine,
    required this.otherUser,
  });

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.66;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            UserAvatar(
              size: 24,
              initials: otherUser.initials,
              photoUrl: otherUser.photoUrl,
              avatarId: otherUser.avatarId,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? const Color(0xFFE8F5EA) : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    boxShadow: isMine
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.black.withValues(alpha: 0.07),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Text(
                    text,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
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

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: AppTextStyles.body.copyWith(
                    color: AppColors.muted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton.filled(
              onPressed: enabled && !sending ? onSend : null,
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              color: AppColors.white,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.4,
                ),
                padding: EdgeInsets.zero,
              ),
              tooltip: 'Send',
            ),
          ),
        ],
      ),
    );
  }
}
