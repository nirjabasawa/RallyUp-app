import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/invite.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/courts/court_network_image.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../../widgets/user_avatar.dart';
import '../main_shell_nav.dart';
import 'invites_page.dart';
import 'nearby_players_page.dart';

/// Success screen shown after `InviteService.createInvite` succeeds.
///
/// The visual rhythm (`InviteSentSuccessIcon` graphic, action button
/// pair, page title) is the same as the previous mock. The middle
/// "summary card" was a static `InviteSentSummaryCard` with a baked-in
/// Alex Johnson + Central Park placeholder; it's replaced with a
/// `_RealInviteSummaryCard` here that reads the same data shape from
/// the live [Invite] passed in.
class InviteSentPage extends StatelessWidget {
  final Invite invite;

  const InviteSentPage({super.key, required this.invite});

  void _openInvites(BuildContext context) {
    // Open the unified InvitesPage with the Sent tab selected so the
    // user lands on the invite they just created.
    Navigator.push(
      context,
      _fadeRoute<void>(const InvitesPage(initialTab: InviteTab.sent)),
    );
  }

  void _backToPlayers(BuildContext context) {
    // Pop everything pushed above AuthGate (the navigator's first
    // route) so the user lands back on the existing MainShell, then
    // push NearbyPlayersPage on top — keeps AuthGate in the stack so
    // logout can't drop into a blank page later.
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.push(context, _fadeRoute<void>(const NearbyPlayersPage()));
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFAFA),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                42,
                AppSpacing.pageHorizontal,
                AppSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xxl,
                ),
                child: Column(
                  children: [
                    const InviteSentSuccessIcon(),
                    const SizedBox(height: AppSpacing.lg),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          height: 1.2,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Your match invite has been sent to\n',
                          ),
                          TextSpan(
                            text: '${invite.toUserName}.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    _RealInviteSummaryCard(invite: invite),
                    const SizedBox(height: AppSpacing.xxl),
                    InviteSentActionButtons(
                      onViewInvitesTap: () => _openInvites(context),
                      onBackToPlayersTap: () => _backToPlayers(context),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      'Invite Sent!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Real-data variant of the old `InviteSentSummaryCard`. Same shadow
/// + border-radius rhythm so the visual surface matches the prior
/// mock; everything inside is fed by [Invite].
class _RealInviteSummaryCard extends StatelessWidget {
  final Invite invite;

  const _RealInviteSummaryCard({required this.invite});

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('EEE, MMM d, y').format(invite.date);
    final spotsLeft =
        invite.playersRequired - invite.effectiveJoinedCountAtSend;
    final spotsLabel = spotsLeft <= 0
        ? 'Match was full'
        : spotsLeft == 1
        ? '1 spot left at send'
        : '$spotsLeft spots left at send';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                size: 44,
                initials: invite.toUserInitials,
                photoUrl: invite.toUserPhotoUrl,
                avatarId: invite.toUserAvatarId,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.toUserName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      invite.sportType,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CourtNetworkImage(
                    url: invite.courtImageUrl.isEmpty
                        ? null
                        : invite.courtImageUrl,
                    iconSize: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: AppSpacing.md),
          _InviteSentInfoLine(
            icon: Icons.location_on_outlined,
            child: Text(
              invite.courtAddress.isEmpty
                  ? invite.courtName
                  : invite.courtAddress,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InviteSentInfoLine(
            icon: Icons.calendar_today_outlined,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dateText,
                    style: AppTextStyles.bodyMedium.copyWith(height: 1.15),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${_formatTime(context, invite.startTime)} - '
                  '${_formatTime(context, invite.endTime)}',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _InviteSentInfoLine(
            icon: Icons.groups_2_outlined,
            child: Text(
              spotsLabel,
              style: AppTextStyles.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
}

class _InviteSentInfoLine extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _InviteSentInfoLine({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brightGreen, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: child),
      ],
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
