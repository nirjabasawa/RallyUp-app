import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/screens/my_bookings_page.dart';
import 'package:rallyup/screens/player_details/group_chat_page.dart';

import '../../models/open_match.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/sport_emoji.dart';
import '../../widgets/courts/court_network_image.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/primary_button.dart';

/// Success screen after [OpenMatchService.joinOpenMatch] succeeds.
///
/// Visual rhythm mirrors [BookingConfirmedPage] so the join-success
/// flow feels like a natural sibling of the private-booking
/// confirmation: shared confetti graphic, same court-card layout,
/// same summary-row block, same primary/outlined button pair. The
/// data is real Firestore — the page just feeds the post-join
/// [OpenMatch] snapshot returned by the service.
class MatchJoinedPage extends StatelessWidget {
  final OpenMatch match;

  const MatchJoinedPage({super.key, required this.match});

  void _openGroupChat(BuildContext context) {
    // Push the real group chat for the just-joined match. The page
    // will idempotently `createOrUpdateGroupThreadForMatch` and
    // add the current user as a participant on entry.
    Navigator.push(
      context,
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => GroupChatPage(match: match),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _openMyBookings(BuildContext context) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MyBookingsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
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
    final emoji = sportEmojiFor(match.sportType);
    final dateText = DateFormat('EEE, MMM d, y').format(match.date);
    final timeText =
        '${_formatTime(context, match.startTime)} - '
        '${_formatTime(context, match.endTime)}';
    final shareText = '\$${match.pricePerPlayer.toStringAsFixed(2)}';
    final spotsValue = match.spotsLeft == 1
        ? '1 spot'
        : '${match.spotsLeft} spots';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                8,
                AppSpacing.pageHorizontal,
                20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    const SizedBox(height: 2),
                    const _ConfirmationGraphic(),
                    const SizedBox(height: 2),
                    Text(
                      'Match Joined!',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "You're all set.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromARGB(18, 0, 0, 0),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 150,
                                height: 110,
                                child: CourtNetworkImage(
                                  url: match.courtImageUrl.isEmpty
                                      ? null
                                      : match.courtImageUrl,
                                  iconSize: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      match.courtName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (match.courtAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        match.courtAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      '$emoji  ${match.sportType}',
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      dateText,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      timeText,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _SummaryRow(label: 'Host', value: match.hostName),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Your share',
                      value: shareText,
                      valueColor: AppColors.primary,
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(
                      label: 'Players',
                      value:
                          '${match.effectiveJoinedCount} / '
                          '${match.playersRequired}',
                    ),
                    const SizedBox(height: 10),
                    _SummaryRow(label: 'Spots left', value: spotsValue),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: const Icon(
                              Icons.attach_money_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please pay your share directly to the host.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      text: 'Go to Group Chat',
                      height: 48,
                      backgroundColor: AppColors.primary,
                      onPressed: () => _openGroupChat(context),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => _openMyBookings(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        child: Text(
                          'View My Bookings',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
    );
  }
}

/// Same confetti + check graphic used by [BookingConfirmedPage] —
/// kept as a private mirror rather than imported so the booking page
/// is the single source of truth for its own widget and the two
/// success screens stay visually identical without coupling them.
class _ConfirmationGraphic extends StatelessWidget {
  const _ConfirmationGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/images/confetti.png',
            width: 400,
            height: 400,
            fit: BoxFit.contain,
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: Color(0xFF1DB954),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    );
    final valueStyle = AppTextStyles.bodyMedium.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: valueColor ?? AppColors.textPrimary,
    );

    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}
