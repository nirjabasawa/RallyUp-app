import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/open_match.dart';
import '../../providers/auth_provider.dart';
import '../../services/invite_service.dart';
import '../../services/open_match_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/courts/court_network_image.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../main_shell_nav.dart';
import 'invite_sent_page.dart';

/// Lets the signed-in host pick one of THEIR existing open matches
/// and send an invite to [otherUser]. Strictly real data — no
/// hardcoded court/date/time. The page lists every hosted match that
/// is still actionable for [otherUser]:
///
///   * not cancelled
///   * not full
///   * end time still in the future
///   * [otherUser] isn't already in `joinedPlayerIds`
///   * [otherUser] doesn't already have a pending/accepted invite
///     for that match (server reconfirms inside InviteService)
///
/// If the host has no qualifying matches the page renders an empty
/// state pointing them at the booking flow.
class InviteToMatchPage extends StatefulWidget {
  final AppUser otherUser;

  const InviteToMatchPage({super.key, required this.otherUser});

  @override
  State<InviteToMatchPage> createState() => _InviteToMatchPageState();
}

class _InviteToMatchPageState extends State<InviteToMatchPage> {
  final OpenMatchService _openMatchService = OpenMatchService();
  final InviteService _inviteService = InviteService();

  String? _selectedMatchId;
  bool _sending = false;

  void _goBackToProfile(BuildContext context) {
    Navigator.maybePop(context);
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

  DateTime _endDateTime(OpenMatch m) {
    final parts = m.endTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final min = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(m.date.year, m.date.month, m.date.day, h, min);
  }

  /// Filter to matches the host can still invite [otherUser] into.
  /// Sorted soonest-first so the next match the host is about to play
  /// surfaces at the top.
  List<OpenMatch> _eligibleMatches(List<OpenMatch> all, String hostUid) {
    final now = DateTime.now();
    final filtered = all.where((m) {
      if (m.hostUid != hostUid) return false;
      if (m.isCancelled) return false;
      if (m.isFull) return false;
      if (m.effectiveJoinedCount >= m.playersRequired) return false;
      if (!_endDateTime(m).isAfter(now)) return false;
      if (m.joinedPlayerIds.contains(widget.otherUser.uid)) return false;
      return true;
    }).toList();
    filtered.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      return a.startTime.compareTo(b.startTime);
    });
    return filtered;
  }

  String _inviteErrorText(StateError e) {
    switch (e.message) {
      case 'match-not-found':
        return 'This match no longer exists.';
      case 'not-host':
        return "You're no longer the host of this match.";
      case 'match-cancelled':
        return 'This match has been cancelled.';
      case 'match-full':
        return 'This match is already full.';
      case 'invitee-is-host':
        return "You can't invite the host.";
      case 'invitee-already-joined':
        return '${widget.otherUser.displayName} has already joined this match.';
      case 'duplicate-invite':
        return '${widget.otherUser.displayName} already has an invite for this match.';
      default:
        return "Couldn't send invite. Try again.";
    }
  }

  Future<void> _sendInvite(AppUser host, OpenMatch match) async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      final invite = await _inviteService.createInvite(
        fromUser: host,
        toUser: widget.otherUser,
        match: match,
      );
      if (!mounted) return;
      navigator.pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => InviteSentPage(invite: invite),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(_inviteErrorText(e))));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send invite. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFA),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => switchToMainShellTab(context, index),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _InviteHeader(onBackTap: () => _goBackToProfile(context)),
            Expanded(
              child: me == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: Text('Sign in to send invites.'),
                      ),
                    )
                  : StreamBuilder<List<OpenMatch>>(
                      stream: _openMatchService.streamMatchesForUser(me.uid),
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
                        final eligible = _eligibleMatches(
                          snapshot.data ?? const <OpenMatch>[],
                          me.uid,
                        );
                        // If the host has no candidate match, lock the
                        // selection state so a stale id from a prior
                        // stream emission doesn't survive into a tap.
                        if (eligible.isEmpty) {
                          _selectedMatchId = null;
                        } else if (_selectedMatchId != null &&
                            !eligible.any((m) => m.id == _selectedMatchId)) {
                          _selectedMatchId = null;
                        }
                        _selectedMatchId ??= eligible.isNotEmpty
                            ? eligible.first.id
                            : null;

                        return ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.pageHorizontal,
                            AppSpacing.lg,
                            AppSpacing.pageHorizontal,
                            AppSpacing.lg,
                          ),
                          children: [
                            InvitePlayerCard(user: widget.otherUser),
                            const SizedBox(height: AppSpacing.lg),
                            if (eligible.isEmpty)
                              const _NoHostedMatchesCard()
                            else ...[
                              Text(
                                'Choose one of your open matches',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              for (final m in eligible) ...[
                                _HostedMatchTile(
                                  match: m,
                                  selected: m.id == _selectedMatchId,
                                  formatTime: _formatTime,
                                  onTap: () =>
                                      setState(() => _selectedMatchId = m.id),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              PrimaryInviteButton(
                                onPressed: _sending
                                    ? null
                                    : () {
                                        final id = _selectedMatchId;
                                        if (id == null) return;
                                        final picked = eligible.firstWhere(
                                          (m) => m.id == id,
                                        );
                                        _sendInvite(me, picked);
                                      },
                              ),
                            ],
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

/// One hosted-match row inside the picker. Wrapped in
/// [InviteToMatchSurface] so the existing card shadow/radius is
/// preserved exactly — no UI redesign.
class _HostedMatchTile extends StatelessWidget {
  final OpenMatch match;
  final bool selected;
  final String Function(BuildContext context, String hhmm) formatTime;
  final VoidCallback onTap;

  const _HostedMatchTile({
    required this.match,
    required this.selected,
    required this.formatTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, MMM d, y').format(match.date);
    final timeText =
        '${formatTime(context, match.startTime)} - '
        '${formatTime(context, match.endTime)}';
    final spotsLeft = match.spotsLeft;
    final spotsLabel = spotsLeft == 1 ? '1 spot left' : '$spotsLeft spots left';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 64,
                height: 64,
                child: CourtNetworkImage(
                  url: match.courtImageUrl.isEmpty ? null : match.courtImageUrl,
                  iconSize: 22,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.sportType} • ${match.courtName}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeText,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${match.effectiveJoinedCount} / '
                    '${match.playersRequired} players · $spotsLabel',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4),
              child: Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : AppColors.muted,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoHostedMatchesCard extends StatelessWidget {
  const _NoHostedMatchesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_tennis_rounded,
            size: 36,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No open matches available to invite this player.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create an open match from the Courts tab to invite them.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteHeader extends StatelessWidget {
  final VoidCallback? onBackTap;

  const _InviteHeader({this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(bottom: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: AppSpacing.xs,
            child: IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
              tooltip: 'Back',
            ),
          ),
          Positioned(
            left: 72,
            right: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Invite to Match',
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 22),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Send an invite to play together',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
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
