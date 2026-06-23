import 'package:flutter/material.dart';

import '../../models/booking_draft.dart';
import '../../models/court.dart';
import '../../screens/confirm_booking_page.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'number_picker_sheet.dart';

/// Open Match players setup. Lets the host pick how many players the
/// match needs and how many are already confirmed, using the existing
/// [NumberPickerSheet] for both numeric inputs.
///
/// IMPORTANT — Open Match end-to-end integration (writing an
/// `open_matches/{id}` doc, invites, match-host visibility, slot
/// reservation) is intentionally NOT done in this phase. The sheet
/// now collects the players counts into a [BookingDraft] and routes
/// to `ConfirmBookingPage` — the "coming next" SnackBar only fires
/// on the review page when the user taps Confirm Open Match.
///
/// The Court / date / time the user picked in `BookCourtSheet` are
/// threaded through here so the future Open Match implementation can
/// be wired in without touching the parent overlay again.
class PlayersSetupSheet extends StatefulWidget {
  final Court court;
  final String sportType;
  final DateTime date;
  final String startTime;
  final String endTime;

  const PlayersSetupSheet({
    super.key,
    required this.court,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<PlayersSetupSheet> createState() => _PlayersSetupSheetState();
}

class _PlayersSetupSheetState extends State<PlayersSetupSheet> {
  int _playersRequired = 4;
  int _playersConfirmed = 1;

  int get _playersStillRequired {
    final value = _playersRequired - _playersConfirmed;
    return value < 0 ? 0 : value;
  }

  Future<void> _pickRequiredPlayers() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NumberPickerSheet(
        title: 'No. of players required',
        initialValue: _playersRequired,
      ),
    );
    if (picked != null) {
      setState(() {
        _playersRequired = picked;
        if (_playersConfirmed > _playersRequired) {
          _playersConfirmed = _playersRequired;
        }
      });
    }
  }

  Future<void> _pickConfirmedPlayers() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NumberPickerSheet(
        title: 'Players already confirmed',
        initialValue: _playersConfirmed,
      ),
    );
    if (picked != null) {
      setState(() {
        _playersConfirmed = picked > _playersRequired
            ? _playersRequired
            : picked;
      });
    }
  }

  /// Build an Open Match draft and route into ConfirmBookingPage.
  /// No Firestore writes happen here — the "coming next" message only
  /// fires when the user taps the final Confirm button on the review
  /// page. We pop both this sheet AND the BookCourtSheet under it so
  /// the user lands on the review page with a clean back stack
  /// (BackButton there returns to CourtDetails).
  void _reviewOpenMatch() {
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final draft = BookingDraft(
      court: widget.court,
      sportType: widget.sportType,
      date: widget.date,
      startTime: widget.startTime,
      endTime: widget.endTime,
      matchType: BookingDraft.matchTypeOpen,
      playersRequired: _playersRequired,
      playersConfirmed: _playersConfirmed,
    );
    Navigator.of(context).pop(); // close players-setup sheet
    Navigator.of(context).maybePop(); // close BookCourtSheet under it
    rootNavigator.push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => ConfirmBookingPage(draft: draft),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required int value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$value',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          24,
          18,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Match — Players',
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.court.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Players required',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              label: 'No. of players required',
              value: _playersRequired,
              onTap: _pickRequiredPlayers,
            ),
            const SizedBox(height: 14),
            Text(
              'Already confirmed',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              label: 'Players already confirmed (incl. you)',
              value: _playersConfirmed,
              onTap: _pickConfirmedPlayers,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Still need',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _playersStillRequired == 1
                        ? '1 player'
                        : '$_playersStillRequired players',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _reviewOpenMatch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Review Match',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
