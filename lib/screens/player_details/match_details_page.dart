import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/screens/player_details/group_chat_page.dart';
import 'package:rallyup/screens/player_details/match_joined_page.dart';
import 'package:rallyup/screens/player_details/message_page.dart';

import '../../models/app_notification.dart';
import '../../models/open_match.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/open_match_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/sport_emoji.dart';
import '../../widgets/court_details/court_image_carousel.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../../widgets/rally_header.dart';
import '../../widgets/user_avatar.dart';

/// Match details view. Join routes through
/// [OpenMatchService.joinOpenMatch], whose transaction rejects
/// host-self-join / duplicate / full / cancelled inside one atomic
/// read-write — two devices racing for the last spot can't both
/// succeed.
class MatchDetailsPage extends StatefulWidget {
  final OpenMatch match;

  const MatchDetailsPage({super.key, required this.match});

  @override
  State<MatchDetailsPage> createState() => _MatchDetailsPageState();
}

class _MatchDetailsPageState extends State<MatchDetailsPage> {
  final OpenMatchService _openMatchService = OpenMatchService();
  final NotificationService _notificationService = NotificationService();
  final UserService _userService = UserService();

  bool _joining = false;
  bool _openingHostMessage = false;
  OpenMatch? _localMatch;

  OpenMatch get _match => _localMatch ?? widget.match;

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
  }

  /// Reads the host's full [AppUser] and pushes the DM page.
  /// Falls back to a SnackBar if the read fails.
  Future<void> _openHostMessage(BuildContext context) async {
    if (_openingHostMessage) return;
    // Capture both before the await so we don't touch BuildContext
    // across the async gap.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _openingHostMessage = true);
    try {
      final host = await _userService.getUser(_match.hostUid);
      if (!mounted) return;
      if (host == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't load the host's profile.")),
        );
        return;
      }
      navigator.push(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => MessagePage(otherUser: host),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't load the host's profile.")),
      );
    } finally {
      if (mounted) setState(() => _openingHostMessage = false);
    }
  }

  void _openGroupChat(BuildContext context) {
    // GroupChatPage calls `createOrUpdateGroupThreadForMatch` on
    // entry so a host with no messages yet still lands in a usable
    // thread.
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GroupChatPage(match: _match),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Confirm-join dialog → transactional join → MatchJoinedPage.
  void _showJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'You will join this match and the host will be notified.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _joining
                        ? null
                        : () {
                            Navigator.pop(dialogContext);
                            _joinMatch();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Yes, Join',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join this match?',
                  style: AppTextStyles.sectionTitle.copyWith(fontSize: 18),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _joinMatch() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join this match.')),
      );
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _joining = true);
    try {
      final updated = await _openMatchService.joinOpenMatch(
        match: _match,
        user: me,
      );
      // Best-effort host notification.
      _notificationService
          .createNotification(
            userId: updated.hostUid,
            title: 'Player joined your match',
            body:
                '${me.displayName} joined your match at ${updated.courtName}.',
            type: AppNotification.typeMatchJoined,
            targetType: AppNotification.targetMatch,
            targetId: updated.id,
          )
          .catchError((_) {});
      if (!mounted) return;
      rootNavigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => MatchJoinedPage(match: updated),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on StateError catch (e) {
      if (!mounted) {
        messenger.showSnackBar(SnackBar(content: Text(_joinErrorText(e))));
        return;
      }
      setState(() => _joining = false);
      messenger.showSnackBar(SnackBar(content: Text(_joinErrorText(e))));
    } catch (_) {
      if (!mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text("Couldn't join this match. Try again.")),
        );
        return;
      }
      setState(() => _joining = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't join this match. Try again.")),
      );
    }
  }

  String _joinErrorText(StateError e) {
    switch (e.message) {
      case 'match-not-found':
        return 'This match no longer exists.';
      case 'match-cancelled':
        return 'The host cancelled this match.';
      case 'match-full':
        return 'This match is already full.';
      case 'host-cannot-join':
        return "You're the host of this match.";
      case 'already-joined':
        return "You've already joined this match.";
      case 'schedule-conflict':
        return 'You already have another booking or match during this time.';
      default:
        return "Couldn't join this match. Try again.";
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

  Widget _buildPlayerSlot({required Widget avatar, required String label}) {
    return SizedBox(
      width: 84,
      child: Column(
        children: [
          SizedBox(width: 60, height: 60, child: Center(child: avatar)),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initialsFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final match = _match;
    final me = context.watch<AuthProvider>().currentUser;
    final dateText = DateFormat('EEE, MMM d, y').format(match.date);
    final whenText =
        '$dateText · ${_formatTime(context, match.startTime)} - '
        '${_formatTime(context, match.endTime)}';
    final emoji = sportEmojiFor(match.sportType);

    final isHost = me != null && match.isHost(me.uid);
    final hasJoined = me != null && match.hasJoined(me.uid) && !isHost;
    final canJoin =
        me != null &&
        !match.isFull &&
        !match.isCancelled &&
        !isHost &&
        !hasJoined;
    final String ctaLabel;
    final VoidCallback? ctaTap;
    if (me == null) {
      ctaLabel = 'Sign in to join';
      ctaTap = null;
    } else if (isHost) {
      ctaLabel = "You're the host";
      ctaTap = null;
    } else if (hasJoined) {
      ctaLabel = 'You joined';
      ctaTap = null;
    } else if (match.isCancelled) {
      ctaLabel = 'Match cancelled';
      ctaTap = null;
    } else if (match.isFull) {
      ctaLabel = 'Match Full';
      ctaTap = null;
    } else if (_joining) {
      ctaLabel = 'Joining…';
      ctaTap = null;
    } else {
      ctaLabel = 'Join Match';
      ctaTap = () => _showJoinDialog(context);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
      body: SafeArea(
        child: Column(
          children: [
            RallyHeader(
              title: 'Match Details',
              showBackButton: true,
              showNotificationButton: false,
              onBackTap: () => Navigator.pop(context),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  AppSpacing.sm,
                  AppSpacing.pageHorizontal,
                  130,
                ),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CourtImageCarousel(
                      imageUrls: match.courtImageUrls,
                      height: 170,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(match.courtName, style: AppTextStyles.sectionTitle),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$emoji  ${match.sportType}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PlayerDetailsInfoRow(
                    icon: Icons.calendar_today_outlined,
                    title: whenText,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PlayerDetailsInfoRow(
                    icon: Icons.location_on_outlined,
                    title: match.courtName,
                    subtitle: match.courtAddress.isEmpty
                        ? null
                        : match.courtAddress,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PlayerDetailsInfoRow(
                    icon: Icons.groups_2_outlined,
                    title: match.isFull
                        ? '${match.joinedCount} / ${match.playersRequired}'
                              ' players joined · Full'
                        : '${match.joinedCount} / ${match.playersRequired}'
                              ' players joined · ${match.spotsLeft} '
                              '${match.spotsLeft == 1 ? "spot left" : "spots left"}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PlayerDetailsInfoRow(
                    icon: Icons.payments_outlined,
                    title:
                        'Each player pays \$${match.pricePerPlayer.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      UserAvatar(
                        size: 24,
                        initials: match.hostInitials,
                        photoUrl: match.hostPhotoUrl,
                        avatarId: match.hostAvatarId,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Hosted by ${match.hostName}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Players (${match.effectiveJoinedCount} / ${match.playersRequired})',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _PlayersStrip(
                    match: match,
                    buildSlot: _buildPlayerSlot,
                    initialsFrom: _initialsFromName,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: ctaTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              ctaLabel,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  if (!canJoin && hasJoined) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, _, _) =>
                                MatchJoinedPage(match: match),
                            transitionsBuilder: (_, animation, _, child) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'View Match Joined',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      // Host → View Group Chat. Non-host → Message Host.
                      onPressed: isHost
                          ? () => _openGroupChat(context)
                          : () => _openHostMessage(context),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        isHost ? 'View Group Chat' : 'Message Host',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Host slot → "+N others" placeholder → real joined players →
/// empty slots up to `playersRequired`.
class _PlayersStrip extends StatelessWidget {
  final OpenMatch match;
  final Widget Function({required Widget avatar, required String label})
  buildSlot;
  final String Function(String name) initialsFrom;

  const _PlayersStrip({
    required this.match,
    required this.buildSlot,
    required this.initialsFrom,
  });

  @override
  Widget build(BuildContext context) {
    final ids = match.joinedPlayerIds;
    final names = match.joinedPlayerNames;
    final slots = <Widget>[];

    // Host first so the "+N others" placeholder sits right after
    // them, before any remote joiners.
    int hostIdx = -1;
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] == match.hostUid) {
        hostIdx = i;
        break;
      }
    }
    if (hostIdx != -1) {
      final hostName = hostIdx < names.length ? names[hostIdx] : match.hostName;
      slots.add(
        buildSlot(
          avatar: UserAvatar(
            size: 60,
            initials: match.hostInitials,
            photoUrl: match.hostPhotoUrl,
            avatarId: match.hostAvatarId,
          ),
          label: '$hostName\n(Host)',
        ),
      );
    }

    if (match.confirmedGuestCount > 0) {
      final guestLabel = match.confirmedGuestCount == 1
          ? '+1 other'
          : '+${match.confirmedGuestCount} others';
      slots.add(
        buildSlot(
          avatar: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: AppColors.textSecondary,
              size: 28,
            ),
          ),
          label: guestLabel,
        ),
      );
    }

    for (var i = 0; i < ids.length; i++) {
      if (i == hostIdx) continue;
      final name = i < names.length ? names[i] : 'Player';
      // Open matches only carry uid + display name per joined
      // player — fall back to initials.
      slots.add(
        buildSlot(
          avatar: PlayerDetailsAvatar(initials: initialsFrom(name), size: 60),
          label: name,
        ),
      );
    }

    final remaining = match.playersRequired - match.effectiveJoinedCount;
    for (var i = 0; i < remaining; i++) {
      // Each empty slot labels itself by remaining spots. First
      // empty reads "N spots", last reads "1 spot".
      final spotsHere = remaining - i;
      slots.add(
        buildSlot(
          avatar: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          label: spotsHere == 1 ? '1 spot' : '$spotsHere spots',
        ),
      );
    }
    if (slots.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < slots.length; i++) ...[
            slots[i],
            if (i < slots.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
