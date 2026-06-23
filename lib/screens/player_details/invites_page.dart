import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/screens/main_shell_nav.dart';

import '../../models/app_user.dart';
import '../../models/invite.dart';
import '../../models/open_match.dart';
import '../../providers/auth_provider.dart';
import '../../services/invite_service.dart';
import '../../services/open_match_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../../widgets/user_avatar.dart';
import 'match_joined_page.dart';

/// Which tab the page opens on. Tab switching is internal state —
/// one screen, no pop-based navigation.
enum InviteTab { sent, received }

/// Sent + Received tabs over real Firestore. Accept / decline are
/// wired on each pending row.
class InvitesPage extends StatefulWidget {
  final InviteTab initialTab;

  const InvitesPage({super.key, this.initialTab = InviteTab.sent});

  @override
  State<InvitesPage> createState() => _InvitesPageState();
}

class _InvitesPageState extends State<InvitesPage> {
  final InviteService _inviteService = InviteService();
  final OpenMatchService _openMatchService = OpenMatchService();

  late InviteTab _selectedTab = widget.initialTab;

  /// Per-invite in-flight lock so a double-tap can't race the server.
  final Set<String> _busyInviteIds = <String>{};

  void _onBottomNavTap(int index) {
    switchToMainShellTab(context, index);
  }

  void _selectTab(InviteTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  String _acceptErrorText(StateError e) {
    switch (e.message) {
      case 'invite-not-found':
        return 'This invite no longer exists.';
      case 'not-invitee':
        return 'You cannot accept this invite.';
      case 'invite-not-pending':
        return 'This invite has already been resolved.';
      case 'match-not-found':
        return 'This match no longer exists.';
      case 'match-cancelled':
        return 'The host cancelled this match.';
      case 'match-full':
        return 'This match is already full.';
      case 'already-joined':
        return "You've already joined this match.";
      case 'host-cannot-join':
        return "You're the host of this match.";
      case 'schedule-conflict':
        return 'You already have another booking or match during this time.';
      default:
        return "Couldn't accept invite. Try again.";
    }
  }

  String _declineErrorText(StateError e) {
    switch (e.message) {
      case 'invite-not-found':
        return 'This invite no longer exists.';
      case 'not-invitee':
        return 'You cannot decline this invite.';
      case 'invite-not-pending':
        return 'This invite has already been resolved.';
      default:
        return "Couldn't decline invite. Try again.";
    }
  }

  Future<void> _accept(AppUser me, Invite invite) async {
    if (_busyInviteIds.contains(invite.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    setState(() => _busyInviteIds.add(invite.id));
    try {
      final updated = await _inviteService.acceptInvite(
        invite: invite,
        user: me,
      );
      if (!mounted) return;
      rootNavigator.pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => MatchJoinedPage(match: updated),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _busyInviteIds.remove(invite.id));
      messenger.showSnackBar(SnackBar(content: Text(_acceptErrorText(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _busyInviteIds.remove(invite.id));
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't accept invite. Try again.")),
      );
    }
  }

  Future<void> _decline(AppUser me, Invite invite) async {
    if (_busyInviteIds.contains(invite.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyInviteIds.add(invite.id));
    try {
      await _inviteService.declineInvite(invite: invite, user: me);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Invite declined')));
    } on StateError catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_declineErrorText(e))));
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't decline invite. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _busyInviteIds.remove(invite.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFA),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const InvitesHeader(),
            InvitesTabBar(
              receivedSelected: _selectedTab == InviteTab.received,
              onSentTap: () => _selectTab(InviteTab.sent),
              onReceivedTap: () => _selectTab(InviteTab.received),
            ),
            Expanded(
              child: me == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('Sign in to view your invites.'),
                      ),
                    )
                  : _selectedTab == InviteTab.sent
                  ? _SentInvitesList(
                      inviteService: _inviteService,
                      openMatchService: _openMatchService,
                      meUid: me.uid,
                    )
                  : _ReceivedInvitesList(
                      inviteService: _inviteService,
                      openMatchService: _openMatchService,
                      me: me,
                      busyInviteIds: _busyInviteIds,
                      onAccept: _accept,
                      onDecline: _decline,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentInvitesList extends StatelessWidget {
  final InviteService inviteService;
  final OpenMatchService openMatchService;
  final String meUid;

  const _SentInvitesList({
    required this.inviteService,
    required this.openMatchService,
    required this.meUid,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Invite>>(
      stream: inviteService.streamSentInvites(meUid),
      builder: (context, snapshot) {
        final waitingFirst =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (waitingFirst) {
          return const Center(child: CircularProgressIndicator());
        }
        final invites = snapshot.data ?? const <Invite>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
            AppSpacing.pageHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Sent Invites (${invites.length})',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (invites.isEmpty)
              const _NoSentInvitesCard()
            else
              for (final inv in invites) ...[
                _SentInviteRow(invite: inv, openMatchService: openMatchService),
                const SizedBox(height: AppSpacing.lg),
              ],
            const SizedBox(height: AppSpacing.sm),
            const InviteInfoCard(),
          ],
        );
      },
    );
  }
}

class _ReceivedInvitesList extends StatelessWidget {
  final InviteService inviteService;
  final OpenMatchService openMatchService;
  final AppUser me;
  final Set<String> busyInviteIds;
  final Future<void> Function(AppUser me, Invite invite) onAccept;
  final Future<void> Function(AppUser me, Invite invite) onDecline;

  const _ReceivedInvitesList({
    required this.inviteService,
    required this.openMatchService,
    required this.me,
    required this.busyInviteIds,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Invite>>(
      stream: inviteService.streamReceivedInvites(me.uid),
      builder: (context, snapshot) {
        final waitingFirst =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (waitingFirst) {
          return const Center(child: CircularProgressIndicator());
        }
        final invites = snapshot.data ?? const <Invite>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
            AppSpacing.pageHorizontal,
            AppSpacing.xxl,
          ),
          children: [
            Text(
              'Received Invites (${invites.length})',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 18,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (invites.isEmpty)
              const _NoReceivedInvitesCard()
            else
              for (final inv in invites) ...[
                _ReceivedInviteRow(
                  invite: inv,
                  openMatchService: openMatchService,
                  busy: busyInviteIds.contains(inv.id),
                  onAccept: () => onAccept(me, inv),
                  onDecline: () => onDecline(me, inv),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            const SizedBox(height: AppSpacing.sm),
            const _ReceivedInvitesInfoCard(),
          ],
        );
      },
    );
  }
}

/// One sent-invite row. Subscribes to the underlying open_match
/// so the live "X / Y joined · N spots left" stays honest. The
/// invite's own snapshot is backstop only.
class _SentInviteRow extends StatelessWidget {
  final Invite invite;
  final OpenMatchService openMatchService;

  const _SentInviteRow({required this.invite, required this.openMatchService});

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
  }

  String _statusLabel() {
    if (invite.isPending) return 'Pending';
    if (invite.isAccepted) return 'Accepted';
    if (invite.isDeclined) return 'Declined';
    return 'Cancelled';
  }

  String _relativeTime(DateTime? t) {
    if (t == null) return 'Just now';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Invited just now';
    if (diff.inMinutes < 60) return 'Invited ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Invited ${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Invited yesterday';
    if (diff.inDays < 7) return 'Invited ${diff.inDays} days ago';
    return 'Invited ${DateFormat('MMM d').format(t)}';
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, MMM d, y').format(invite.date);
    final timeText =
        '${_formatTime(context, invite.startTime)} - '
        '${_formatTime(context, invite.endTime)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                size: 52,
                initials: invite.toUserInitials,
                photoUrl: invite.toUserPhotoUrl,
                avatarId: invite.toUserAvatarId,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.toUserName,
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invite.sportType,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: AppSpacing.md),
          InviteDetailLine(
            icon: Icons.location_on_outlined,
            label: invite.courtName,
          ),
          const SizedBox(height: AppSpacing.sm),
          InviteDetailLine(
            icon: Icons.calendar_today_outlined,
            label: dateText,
            trailing: timeText,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LiveMatchPlayersLine(
            invite: invite,
            openMatchService: openMatchService,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              InviteStatusChip(label: _statusLabel()),
              const Spacer(),
              Flexible(
                child: Text(
                  _relativeTime(invite.createdAt),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.muted,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReceivedInviteRow extends StatelessWidget {
  final Invite invite;
  final OpenMatchService openMatchService;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _ReceivedInviteRow({
    required this.invite,
    required this.openMatchService,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
  }

  String _statusLabel() {
    if (invite.isPending) return 'New invite';
    if (invite.isAccepted) return 'Accepted';
    if (invite.isDeclined) return 'Declined';
    return 'Cancelled';
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, MMM d, y').format(invite.date);
    final timeText =
        '${_formatTime(context, invite.startTime)} - '
        '${_formatTime(context, invite.endTime)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                size: 52,
                initials: invite.fromUserInitials,
                photoUrl: invite.fromUserPhotoUrl,
                avatarId: invite.fromUserAvatarId,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.fromUserName,
                      style: AppTextStyles.sectionTitle.copyWith(
                        fontSize: 18,
                        color: AppColors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${invite.sportType} • Invited you to join',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: AppSpacing.md),
          InviteDetailLine(
            icon: Icons.location_on_outlined,
            label: invite.courtName,
          ),
          const SizedBox(height: AppSpacing.sm),
          InviteDetailLine(
            icon: Icons.calendar_today_outlined,
            label: dateText,
            trailing: timeText,
          ),
          const SizedBox(height: AppSpacing.sm),
          _LiveMatchPlayersLine(
            invite: invite,
            openMatchService: openMatchService,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: AppSpacing.md),
          if (invite.isPending)
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InviteStatusChip(label: _statusLabel()),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _InviteActionButton(
                    label: 'Decline',
                    outlined: true,
                    onPressed: busy ? null : onDecline,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 3,
                  child: _InviteActionButton(
                    label: busy ? 'Working…' : 'Accept',
                    onPressed: busy ? null : onAccept,
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: InviteStatusChip(label: _statusLabel()),
            ),
        ],
      ),
    );
  }
}

/// Players-joined / spots-left line that listens to the underlying
/// OpenMatch via [OpenMatchService.streamOpenMatch] so the count is
/// live for both Sent and Received invite cards. Falls back to the
/// invite snapshot if the match doc has been deleted server-side.
class _LiveMatchPlayersLine extends StatelessWidget {
  final Invite invite;
  final OpenMatchService openMatchService;

  const _LiveMatchPlayersLine({
    required this.invite,
    required this.openMatchService,
  });

  String _snapshotLabel() {
    final required = invite.playersRequired;
    final joined = invite.effectiveJoinedCountAtSend;
    final left = required - joined;
    if (left <= 0) return 'Match was full at send';
    if (left == 1) return '$joined / $required joined · 1 spot left';
    return '$joined / $required joined · $left spots left';
  }

  String _liveLabel(OpenMatch m) {
    if (m.isCancelled) return 'Match cancelled';
    if (m.isFull || m.effectiveJoinedCount >= m.playersRequired) {
      return 'Match full';
    }
    final left = m.spotsLeft;
    final base = '${m.effectiveJoinedCount} / ${m.playersRequired} joined';
    if (left == 1) return '$base · 1 spot left';
    return '$base · $left spots left';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<OpenMatch?>(
      stream: openMatchService.streamOpenMatch(invite.matchId),
      builder: (context, snapshot) {
        // While waiting for the first frame, use the invite snapshot
        // so the row never reads as a bare blank line.
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return InviteDetailLine(
            icon: Icons.groups_2_outlined,
            label: _snapshotLabel(),
          );
        }
        final live = snapshot.data;
        if (live == null) {
          return InviteDetailLine(
            icon: Icons.groups_2_outlined,
            label: 'Match no longer available',
          );
        }
        return InviteDetailLine(
          icon: Icons.groups_2_outlined,
          label: _liveLabel(live),
        );
      },
    );
  }
}

class _InviteActionButton extends StatelessWidget {
  final String label;
  final bool outlined;
  final VoidCallback? onPressed;

  const _InviteActionButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (outlined) {
      return SizedBox(
        height: 38,
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.3),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      height: 38,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      ),
    );
  }
}

class _NoSentInvitesCard extends StatelessWidget {
  const _NoSentInvitesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "You haven't sent any invites yet.",
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoReceivedInvitesCard extends StatelessWidget {
  const _NoReceivedInvitesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              "You haven't received any invites yet.",
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceivedInvitesInfoCard extends StatelessWidget {
  const _ReceivedInvitesInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFEFE),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.muted),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Accepted invites will move to your bookings.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
