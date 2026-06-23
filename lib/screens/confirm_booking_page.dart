import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../models/booking_draft.dart';
import '../providers/auth_provider.dart';
import '../services/booking_service.dart';
import '../services/notification_service.dart';
import '../services/open_match_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/sport_emoji.dart';
import '../widgets/courts/court_network_image.dart';
import '../widgets/main_bottom_nav.dart';
import 'booking_confirmed_page.dart';
import 'main_shell_nav.dart';
import 'player_details/match_details_page.dart';

/// Review-before-confirm. Sits between BookCourtSheet /
/// PlayersSetupSheet and the post-confirm page. Nothing reaches
/// Firestore until "Confirm" runs the create call.
class ConfirmBookingPage extends StatefulWidget {
  final BookingDraft draft;

  const ConfirmBookingPage({super.key, required this.draft});

  @override
  State<ConfirmBookingPage> createState() => _ConfirmBookingPageState();
}

class _ConfirmBookingPageState extends State<ConfirmBookingPage> {
  final BookingService _bookingService = BookingService();
  final OpenMatchService _openMatchService = OpenMatchService();
  final NotificationService _notificationService = NotificationService();
  bool _busy = false;

  Future<void> _confirmPrivateBooking() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to confirm this booking.'),
        ),
      );
      return;
    }
    // Capture before the async gap.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final booking = await _bookingService.createBooking(
        userId: me.uid,
        court: widget.draft.court,
        sportType: widget.draft.sportType,
        date: widget.draft.date,
        startTime: widget.draft.startTime,
        endTime: widget.draft.endTime,
      );
      if (!mounted) return;
      rootNavigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => BookingConfirmedPage(booking: booking),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on StateError catch (e) {
      // Conflict errors translate to specific copy; everything else
      // falls through to the generic message.
      final text =
          _conflictText(e) ?? "Couldn't confirm this booking. Try again.";
      if (!mounted) {
        messenger.showSnackBar(SnackBar(content: Text(text)));
        return;
      }
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (!mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't confirm this booking. Try again."),
          ),
        );
        return;
      }
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't confirm this booking. Try again."),
        ),
      );
    }
  }

  /// Returns null when the error isn't a conflict.
  String? _conflictText(StateError e) {
    switch (e.message) {
      case 'court-occupied':
        return 'This court is already booked for the selected time.';
      case 'schedule-conflict':
        return 'You already have another booking or match during this time.';
      default:
        return null;
    }
  }

  /// Writes `open_matches/{id}`, fires the host notification, and
  /// routes to MatchDetailsPage. No private booking doc is written.
  Future<void> _confirmOpenMatch() async {
    final me = context.read<AuthProvider>().currentUser;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to create this open match.'),
        ),
      );
      return;
    }
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final match = await _openMatchService.createOpenMatch(
        host: me,
        draft: widget.draft,
      );
      // Best-effort host notification.
      _notificationService
          .createNotification(
            userId: match.hostUid,
            title: 'Open match created',
            body: '${match.courtName} is open for players.',
            type: AppNotification.typeOpenMatchCreated,
            targetType: AppNotification.targetMatch,
            targetId: match.id,
          )
          .catchError((_) {});
      if (!mounted) return;
      rootNavigator.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, _, _) => MatchDetailsPage(match: match),
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } on StateError catch (e) {
      // OpenMatchService throws StateError for both legacy
      // host-duplicate messages (already user-facing) and the
      // newer conflict codes — translate the codes first.
      final text = _conflictText(e) ?? e.message;
      if (!mounted) {
        messenger.showSnackBar(SnackBar(content: Text(text)));
        return;
      }
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(text)));
    } catch (_) {
      if (!mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text("Couldn't create this open match. Try again."),
          ),
        );
        return;
      }
      setState(() => _busy = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't create this open match. Try again."),
        ),
      );
    }
  }

  void _onBottomNavTap(int index) {
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
    final draft = widget.draft;
    final dateText = DateFormat('EEE, MMM d, y').format(draft.date);
    final timeText =
        '${_formatTime(context, draft.startTime)} - '
        '${_formatTime(context, draft.endTime)}';
    final emoji = sportEmojiFor(draft.sportType);
    final matchTypeLabel = draft.isOpenMatch ? 'Open match' : 'Private match';
    final priceText = '\$${draft.court.pricePerHour.toStringAsFixed(2)}';
    final totalText = '\$${draft.totalPrice.toStringAsFixed(2)}';
    final imageUrl = draft.court.imageUrls.isNotEmpty
        ? draft.court.imageUrls.first
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                18,
                AppSpacing.pageHorizontal,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Confirm Booking',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageHorizontal,
                  8,
                  AppSpacing.pageHorizontal,
                  24,
                ),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(16, 0, 0, 0),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: CourtNetworkImage(
                                url: imageUrl,
                                iconSize: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    draft.court.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (draft.court.address.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      draft.court.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    '$emoji  ${draft.sportType}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    dateText,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeText,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
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
                  Text(
                    'Booking Details',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Match type',
                    value: matchTypeLabel,
                    valueColor: AppColors.primary,
                  ),
                  if (draft.isOpenMatch) ...[
                    _DetailRow(
                      label: 'Players required',
                      value: '${draft.playersRequired ?? 0}',
                    ),
                    _DetailRow(
                      label: 'Players confirmed',
                      value: '${draft.playersConfirmed ?? 0} (including you)',
                    ),
                    _DetailRow(
                      label: 'Still needed',
                      value: '${draft.playersStillNeeded}',
                    ),
                  ],
                  const Divider(color: AppColors.border, height: 28),
                  Text(
                    'Price Details',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Price per hour', value: priceText),
                  _DetailRow(
                    label: draft.isOpenMatch ? 'Total court price' : 'Total',
                    value: totalText,
                    isBold: !draft.isOpenMatch,
                  ),
                  if (draft.isOpenMatch) ...[
                    // Cost split for Open Match. We divide the court
                    // total by `playersRequired` (clamped to at least
                    // 1 so a misconfigured draft can't divide by zero
                    // — the BookCourtSheet validation already enforces
                    // a positive value, but the model nominally
                    // allows null/0). This matches the host-pays-
                    // their-share model the earlier mock confirmation
                    // surfaced; later phases will track per-player
                    // payment state inside the open match doc.
                    () {
                      final players = (draft.playersRequired ?? 0) <= 0
                          ? 1
                          : (draft.playersRequired ?? 1);
                      final perPlayer = draft.totalPrice / players;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DetailRow(
                            label: 'Split between',
                            value: players == 1
                                ? '1 player'
                                : '$players players',
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Each player pays',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '\$${perPlayer.toStringAsFixed(2)}',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }(),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _busy
                          ? null
                          : (draft.isOpenMatch
                                ? _confirmOpenMatch
                                : _confirmPrivateBooking),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              draft.isOpenMatch
                                  ? 'Create Open Match'
                                  : 'Confirm Booking',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Secure Booking',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 170,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
