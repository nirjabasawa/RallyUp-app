import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/chat_message.dart';
import '../../models/chat_thread.dart';
import '../../models/open_match.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/open_match_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/sport_emoji.dart';
import '../../widgets/courts/court_network_image.dart';
import '../../widgets/main_bottom_nav.dart';
import '../main_shell_nav.dart';

/// Group chat for an open match. Pushed either with an [OpenMatch]
/// (from MatchDetails / MatchJoined) or with a precomputed
/// [threadId] (from GroupMessagesPage). Both paths converge on
/// `_threadId` and reuse the direct-chat send/read APIs.
class GroupChatPage extends StatefulWidget {
  final OpenMatch? match;
  final String? threadId;

  const GroupChatPage({super.key, this.match, this.threadId})
    : assert(
        match != null || threadId != null,
        'GroupChatPage requires either a match or a threadId',
      );

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final ChatService _chatService = ChatService();
  final OpenMatchService _openMatchService = OpenMatchService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _threadId;
  ChatThread? _thread;
  OpenMatch? _match;
  String? _initError;
  bool _sending = false;

  /// Last incoming message we've already marked read — prevents
  /// per-snapshot `markThreadRead` thrashing.
  String? _lastMarkedMessageId;

  @override
  void initState() {
    super.initState();
    _initThread();
  }

  Future<void> _initThread() async {
    try {
      // Path A: opened with a real OpenMatch — ensure the thread
      // exists before streaming.
      if (widget.match != null) {
        await _chatService.createOrUpdateGroupThreadForMatch(widget.match!);
        if (!mounted) return;
        setState(() {
          _match = widget.match;
          _threadId = _chatService.groupThreadIdForMatch(widget.match!.id);
        });
        // Read it back so the header gets the live data.
        final t = await _chatService.getThread(_threadId!);
        if (!mounted) return;
        if (t != null) setState(() => _thread = t);
      } else {
        // Path B: opened with a known thread id. Load the thread,
        // then fetch the open-match snapshot for the header card.
        final id = widget.threadId!;
        final t = await _chatService.getThread(id);
        if (!mounted) return;
        if (t == null) {
          setState(
            () => _initError = 'This group chat is no longer available.',
          );
          return;
        }
        setState(() {
          _thread = t;
          _threadId = id;
        });
        final matchId = t.matchId;
        if (matchId != null && matchId.isNotEmpty) {
          final m = await _openMatchService.getOpenMatch(matchId);
          if (!mounted) return;
          if (m != null) setState(() => _match = m);
        }
      }

      // Mark thread read on open.
      final me = context.read<AuthProvider>().currentUser;
      final id = _threadId;
      if (me != null && id != null) {
        _chatService
            .markThreadRead(threadId: id, uid: me.uid)
            .catchError((_) {});
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _initError = 'Could not open this group chat.');
    }
  }

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

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
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
        senderName: me.displayName,
      );
      if (!mounted) return;
      _textController.clear();
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

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final myUid = me?.uid;
    final thread = _thread;
    final headerTitle =
        thread?.title ??
        (widget.match != null
            ? '${widget.match!.sportType} at ${widget.match!.courtName}'
            : 'Group chat');
    final participantsCount =
        thread?.participantIds.length ?? _match?.joinedPlayerIds.length ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFA),
      bottomNavigationBar: MainBottomNav(
        currentIndex: 1,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _GroupChatHeader(
              title: headerTitle,
              participantsCount: participantsCount,
              onBackTap: () => Navigator.maybePop(context),
            ),
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
                    if (myUid != null) {
                      _maybeMarkRead(messages, myUid);
                    }
                    // Summary card rides at the top of the reversed
                    // list so it sits above the oldest message.
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
                      itemCount: reversed.length + 1,
                      itemBuilder: (context, i) {
                        if (i == reversed.length) {
                          // Oldest slot in a reverse list.
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg,
                            ),
                            child: _GroupMatchSummaryCard(
                              match: _match,
                              thread: _thread,
                              formatTime: _formatTime,
                            ),
                          );
                        }
                        final msg = reversed[i];
                        final isMine = myUid != null && msg.senderUid == myUid;
                        return _GroupChatBubble(
                          text: msg.text,
                          time: _formatClockTime(context, msg.sentAt),
                          isMine: isMine,
                          senderName: msg.senderName,
                          isHost:
                              _match != null &&
                              _match!.hostUid == msg.senderUid,
                        );
                      },
                    );
                  },
                ),
              ),
            _GroupMessageInput(
              controller: _textController,
              sending: _sending,
              enabled: _threadId != null && _initError == null,
              onSend: _send,
            ),
            const SizedBox(height: AppSpacing.xs),
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

class _GroupChatHeader extends StatelessWidget {
  final String title;
  final int participantsCount;
  final VoidCallback? onBackTap;

  const _GroupChatHeader({
    required this.title,
    required this.participantsCount,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final participantsLabel = participantsCount == 1
        ? '1 participant'
        : '$participantsCount participants';

    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBackTap ?? () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: AppColors.textPrimary,
            tooltip: 'Back',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  participantsLabel,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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

class _GroupMatchSummaryCard extends StatelessWidget {
  final OpenMatch? match;
  final ChatThread? thread;
  final String Function(BuildContext context, String hhmm) formatTime;

  const _GroupMatchSummaryCard({
    required this.match,
    required this.thread,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final m = match;
    if (m == null) {
      // Match was deleted — fall back to the thread's snapshot
      // fields so the card still has content.
      final t = thread;
      final title = t?.title ?? 'Open match';
      final court = t?.courtName ?? '';
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 108,
                height: 104,
                child: CourtNetworkImage(
                  url: (t?.imageUrl?.isNotEmpty == true) ? t!.imageUrl : null,
                  iconSize: 28,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (court.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      court,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    final dateText = DateFormat('EEE, d MMM y').format(m.date);
    final timeText =
        '${formatTime(context, m.startTime)} - ${formatTime(context, m.endTime)}';
    final emoji = sportEmojiFor(m.sportType);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 108,
              height: 104,
              child: CourtNetworkImage(
                url: m.courtImageUrl.isEmpty ? null : m.courtImageUrl,
                iconSize: 28,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.courtName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        m.sportType,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateText,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        timeText,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${m.effectiveJoinedCount} / ${m.playersRequired} players',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
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

class _GroupChatBubble extends StatelessWidget {
  final String text;
  final String time;
  final bool isMine;
  final String? senderName;
  final bool isHost;

  const _GroupChatBubble({
    required this.text,
    required this.time,
    required this.isMine,
    required this.senderName,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.66;
    final displaySender = isMine
        ? null
        : (senderName != null && senderName!.isNotEmpty)
        ? (isHost ? '$senderName (Host)' : senderName)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (displaySender != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      displaySender,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
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
                              blurRadius: 5,
                              offset: const Offset(0, 2),
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
                    color: AppColors.muted,
                    fontSize: 11,
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

class _GroupMessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  const _GroupMessageInput({
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
