import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/id_verification.dart';
import '../../providers/auth_provider.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../../widgets/user_avatar.dart';
import '../main_shell_nav.dart';
import 'invite_to_match_page.dart';
import 'message_page.dart';
import 'nearby_players_page.dart';

/// Read-only profile view for another player, driven entirely off
/// the passed [AppUser] — no fake data.
class PlayerProfilePage extends StatelessWidget {
  final AppUser user;
  final String distance;

  const PlayerProfilePage({
    super.key,
    required this.user,
    required this.distance,
  });

  static const String _heroImagePath =
      'assets/images/player_details/player_profile/player_profile_hero.png';

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
  }

  void _openMessage(BuildContext context) {
    Navigator.push(context, _fadeRoute<void>(MessagePage(otherUser: user)));
  }

  void _openInviteToMatch(BuildContext context) {
    Navigator.push(
      context,
      _fadeRoute<void>(InviteToMatchPage(otherUser: user)),
    );
  }

  void _goBackToPlayers(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.maybePop(context);
      return;
    }

    Navigator.pushReplacement(
      context,
      _fadeRoute<void>(const NearbyPlayersPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = user.location?.displayLabel;
    final hasBio = user.bio != null && user.bio!.trim().isNotEmpty;
    final verificationLabel = IdVerification.labelFor(user.idVerification);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _PlayerProfileHero(
                heroImagePath: _heroImagePath,
                user: user,
                onBackTap: () => _goBackToPlayers(context),
              ),
            ),
            SliverToBoxAdapter(
              // Stretch so About / Sports / Availability take full
              // width. The hero / name / chips / action buttons
              // center themselves explicitly.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user.displayName,
                    style: AppTextStyles.pageTitle.copyWith(fontSize: 20),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Chips: real sports + distance + verification.
                  // No skill-level yet.
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pageHorizontal,
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final sport in user.sports)
                          PlayerDetailsChip(label: sport),
                        PlayerDetailsChip(
                          label: distance,
                          icon: Icons.location_on_outlined,
                        ),
                        if (locationLabel != null && locationLabel.isNotEmpty)
                          PlayerDetailsChip(
                            label: locationLabel,
                            icon: Icons.place_outlined,
                          ),
                        PlayerDetailsChip(
                          label: verificationLabel,
                          icon: Icons.verified_user_outlined,
                          selected:
                              user.idVerification?.status ==
                              IdVerificationStatus.verified,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  PlayerProfileActionButtons(
                    onConnectTap: () => _openMessage(context),
                    onInviteTap: () => _openInviteToMatch(context),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _PlayerProfileAbout(
                    firstName: user.firstName,
                    bio: hasBio ? user.bio!.trim() : null,
                    sports: user.sports,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _PlayerProfileAvailability(availability: user.availability),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero using the shared [UserAvatar] priority chain (photoUrl →
/// avatarId → initials). The check-mark badge was removed because not every
/// player is verified — verification is surfaced via the chip row below
/// instead, where it can reflect real state from [IdVerification].
class _PlayerProfileHero extends StatelessWidget {
  final String heroImagePath;
  final AppUser user;
  final VoidCallback? onBackTap;

  const _PlayerProfileHero({
    required this.heroImagePath,
    required this.user,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: 176,
            width: double.infinity,
            child: Image.asset(heroImagePath, fit: BoxFit.cover),
          ),
          Positioned.fill(
            bottom: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.black.withValues(alpha: 0.18),
                    AppColors.black.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xl,
            child: IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
              tooltip: 'Back',
            ),
          ),
          Positioned(
            right: AppSpacing.xs,
            top: AppSpacing.xl,
            child: PopupMenuButton<String>(
              tooltip: 'More',
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textPrimary,
              ),
              onSelected: (value) {
                if (value == 'report') {
                  _showReportPlayerDialog(context, user);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text('Report user'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: UserAvatar(
                  size: 76,
                  initials: user.initials,
                  photoUrl: user.photoUrl,
                  avatarId: user.avatarId,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Captures a free-text reason and persists a report against [target]
/// via [FeedbackService.reportUser]. Shows a confirmation SnackBar
/// once the write lands. Anonymous reports (no signed-in user) are
/// blocked with a clear message so the moderator queue stays useful.
Future<void> _showReportPlayerDialog(
  BuildContext context,
  AppUser target,
) async {
  final me = context.read<AuthProvider>().currentUser;
  final messenger = ScaffoldMessenger.of(context);
  if (me == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Sign in to report a user.')),
    );
    return;
  }
  if (me.uid == target.uid) {
    // Can't really happen via UI (the profile page is for other
    // users) but guard anyway.
    return;
  }

  final controller = TextEditingController();
  final reason = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      String? error;
      return StatefulBuilder(
        builder: (statefulContext, setLocal) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text('Report ${target.displayName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us what happened. The RallyUp team will review '
                  'every report.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Spam, harassment, no-show, …',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final entered = controller.text.trim();
                  if (entered.isEmpty) {
                    setLocal(() => error = 'Please describe the issue.');
                    return;
                  }
                  Navigator.pop(dialogContext, entered);
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
  // Defer the controller dispose to the next frame. Calling
  // `controller.dispose()` synchronously immediately after the
  // `await showDialog` returns races the dialog's exit animation —
  // the TextField at line 329 is still in the tree (the route's
  // overlay is fading out) and its `_AnimatedState.didUpdateWidget`
  // tries to re-subscribe to the controller's listenable on the
  // next frame, throwing "A TextEditingController was used after
  // being disposed."
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });
  if (reason == null) return;
  try {
    await FeedbackService().reportUser(
      reporterId: me.uid,
      reporterName: me.displayName,
      reportedUserId: target.uid,
      reportedUserName: target.displayName,
      reason: reason,
    );
    // Same race applies to the SnackBar — defer so it doesn't
    // insert into the tree while the dialog overlay is still
    // animating out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Thanks. Your report has been submitted.'),
        ),
      );
    });
  } catch (_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't submit the report. Please try again."),
        ),
      );
    });
  }
}

/// About section that renders the user's bio if they wrote one, otherwise
/// a single "No bio added yet." line. Sports are rendered as real pills
/// using the user's actual sports list — there is no skill-level field
/// yet, so that part of the legacy mock-up is intentionally absent.
class _PlayerProfileAbout extends StatelessWidget {
  final String firstName;
  final String? bio;
  final List<String> sports;

  const _PlayerProfileAbout({
    required this.firstName,
    required this.bio,
    required this.sports,
  });

  @override
  Widget build(BuildContext context) {
    final aboutTitle = firstName.trim().isEmpty
        ? 'About'
        : 'About ${firstName.trim()}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            aboutTitle,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            bio ?? 'No bio added yet.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          if (sports.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sports',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final sport in sports)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      sport,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.brightGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Availability that mirrors what the user actually saved in
/// `AvailabilitySlot`s. Falls back to a single "No availability set" line
/// when the map is empty — the old hard-coded seven-day list is gone.
class _PlayerProfileAvailability extends StatelessWidget {
  final Map<String, AvailabilitySlot> availability;

  const _PlayerProfileAvailability({required this.availability});

  // Canonical week order used by EditAvailabilityScreen; matters for the
  // day-chip row + the day-wise timing list to stay consistent.
  static const List<String> _weekOrder = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static const Map<String, String> _shortToLong = {
    'Sun': 'Sunday',
    'Mon': 'Monday',
    'Tue': 'Tuesday',
    'Wed': 'Wednesday',
    'Thu': 'Thursday',
    'Fri': 'Friday',
    'Sat': 'Saturday',
  };

  String _formatTime12h(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final tod = TimeOfDay(hour: h, minute: m);
    return MaterialLocalizations.of(context).formatTimeOfDay(tod);
  }

  @override
  Widget build(BuildContext context) {
    final activeDays = _weekOrder
        .where(availability.containsKey)
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability',
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (activeDays.isEmpty)
            Text(
              'No availability set',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            Text('Days', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final day in activeDays) AvailabilityDayChip(label: day),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Daywise Timings',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < activeDays.length; i++) ...[
              DaywiseTimingRow(
                day: _shortToLong[activeDays[i]] ?? activeDays[i],
                time:
                    '${_formatTime12h(context, availability[activeDays[i]]!.start)}'
                    ' - '
                    '${_formatTime12h(context, availability[activeDays[i]]!.end)}',
              ),
              if (i < activeDays.length - 1)
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
            ],
          ],
        ],
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
