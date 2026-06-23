import 'court.dart';

/// In-memory selections from `BookCourtSheet` / `PlayersSetupSheet`,
/// reviewed on `ConfirmBookingPage` and only written to Firestore
/// when the user confirms.
class BookingDraft {
  static const String matchTypePrivate = 'private';
  static const String matchTypeOpen = 'open';

  final Court court;
  final String sportType;
  final DateTime date;

  /// 24-hour `HH:mm`.
  final String startTime;
  final String endTime;
  final String matchType;

  /// Only meaningful for open-match drafts; null for private.
  final int? playersRequired;
  final int? playersConfirmed;

  const BookingDraft({
    required this.court,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.matchType,
    this.playersRequired,
    this.playersConfirmed,
  });

  bool get isOpenMatch => matchType == matchTypeOpen;
  bool get isPrivateMatch => matchType == matchTypePrivate;

  /// Open match only — clamped to non-negative.
  int get playersStillNeeded {
    final req = playersRequired ?? 0;
    final con = playersConfirmed ?? 0;
    final diff = req - con;
    return diff < 0 ? 0 : diff;
  }

  /// Slots are 1-hour for now; when variable-length lands, multiply
  /// by hours-in-slot here.
  double get totalPrice => court.pricePerHour;
}
