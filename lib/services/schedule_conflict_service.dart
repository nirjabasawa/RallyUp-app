import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/open_match.dart';

/// Pre-flight schedule checks against the live Firestore state.
///
/// Two independent conflicts are enforced:
///
///   * **Court occupancy** — no two reservations on the same court
///     during an overlapping window. Confirmed private bookings and
///     non-cancelled open matches both count.
///
///   * **User schedule** — no two overlapping sessions for the same
///     real user, even at different courts. Sources: their confirmed
///     bookings, the matches they host, and the matches their uid is
///     in `joinedPlayerIds` for. Anonymous `confirmedGuestCount`
///     guests aren't checked — they have no real uid.
///
/// The overlap test is the canonical interval check:
///
/// ```dart
/// existingStart < newEnd && newStart < existingEnd
/// ```
///
/// String equality on HH:mm is not a substitute — 6:00–7:00 PM and
/// 6:30–7:30 PM are an exact-equality miss but real overlap.
///
/// Throws `StateError('court-occupied')` or
/// `StateError('schedule-conflict')` on detection so callers can pick
/// the right SnackBar copy.
///
/// All Firestore queries are single-field equality so no new
/// composite indexes are required.
class ScheduleConflictService {
  final FirebaseFirestore _db;

  ScheduleConflictService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');
  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('open_matches');

  // ─── Pure helpers ───────────────────────────────────────────────

  static DateTime _combine(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  /// Endpoint-touch is NOT overlap — 6–7 PM next to 7–8 PM is allowed.
  static bool intervalsOverlap({
    required DateTime aStart,
    required DateTime aEnd,
    required DateTime bStart,
    required DateTime bEnd,
  }) {
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  static bool dayTimesOverlap({
    required DateTime aDate,
    required String aStart,
    required String aEnd,
    required DateTime bDate,
    required String bStart,
    required String bEnd,
  }) {
    return intervalsOverlap(
      aStart: _combine(aDate, aStart),
      aEnd: _combine(aDate, aEnd),
      bStart: _combine(bDate, bStart),
      bEnd: _combine(bDate, bEnd),
    );
  }

  // ─── Court occupancy ────────────────────────────────────────────

  Future<bool> isCourtOccupied({
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeBookingId,
    String? excludeMatchId,
  }) async {
    final newStart = _combine(date, startTime);
    final newEnd = _combine(date, endTime);

    final bookingsSnap = await _bookings
        .where('courtId', isEqualTo: courtId)
        .get();
    for (final doc in bookingsSnap.docs) {
      if (excludeBookingId != null && doc.id == excludeBookingId) continue;
      final b = Booking.fromDoc(doc);
      if (!b.isConfirmed) continue;
      if (!_isSameDay(b.date, date)) continue;
      if (intervalsOverlap(
        aStart: _combine(b.date, b.startTime),
        aEnd: _combine(b.date, b.endTime),
        bStart: newStart,
        bEnd: newEnd,
      )) {
        return true;
      }
    }

    final matchesSnap = await _matches
        .where('courtId', isEqualTo: courtId)
        .get();
    for (final doc in matchesSnap.docs) {
      if (excludeMatchId != null && doc.id == excludeMatchId) continue;
      final m = OpenMatch.fromDoc(doc);
      if (m.isCancelled) continue;
      if (!_isSameDay(m.date, date)) continue;
      if (intervalsOverlap(
        aStart: _combine(m.date, m.startTime),
        aEnd: _combine(m.date, m.endTime),
        bStart: newStart,
        bEnd: newEnd,
      )) {
        return true;
      }
    }
    return false;
  }

  // ─── User schedule ──────────────────────────────────────────────

  Future<bool> hasUserConflict({
    required String userId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeBookingId,
    String? excludeMatchId,
  }) async {
    final newStart = _combine(date, startTime);
    final newEnd = _combine(date, endTime);

    // Confirmed bookings owned by this user.
    final bookingsSnap = await _bookings
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in bookingsSnap.docs) {
      if (excludeBookingId != null && doc.id == excludeBookingId) continue;
      final b = Booking.fromDoc(doc);
      if (!b.isConfirmed) continue;
      if (!_isSameDay(b.date, date)) continue;
      if (intervalsOverlap(
        aStart: _combine(b.date, b.startTime),
        aEnd: _combine(b.date, b.endTime),
        bStart: newStart,
        bEnd: newEnd,
      )) {
        return true;
      }
    }

    // Hosted matches.
    final hostedSnap = await _matches.where('hostUid', isEqualTo: userId).get();
    for (final doc in hostedSnap.docs) {
      if (excludeMatchId != null && doc.id == excludeMatchId) continue;
      final m = OpenMatch.fromDoc(doc);
      if (m.isCancelled) continue;
      if (!_isSameDay(m.date, date)) continue;
      if (intervalsOverlap(
        aStart: _combine(m.date, m.startTime),
        aEnd: _combine(m.date, m.endTime),
        bStart: newStart,
        bEnd: newEnd,
      )) {
        return true;
      }
    }

    // Joined matches. Skip host-self entries so they don't double-
    // count against the hosted query above.
    final joinedSnap = await _matches
        .where('joinedPlayerIds', arrayContains: userId)
        .get();
    for (final doc in joinedSnap.docs) {
      if (excludeMatchId != null && doc.id == excludeMatchId) continue;
      final m = OpenMatch.fromDoc(doc);
      if (m.isCancelled) continue;
      if (m.hostUid == userId) continue;
      if (!_isSameDay(m.date, date)) continue;
      if (intervalsOverlap(
        aStart: _combine(m.date, m.startTime),
        aEnd: _combine(m.date, m.endTime),
        bStart: newStart,
        bEnd: newEnd,
      )) {
        return true;
      }
    }

    return false;
  }

  // ─── High-level guards (throw on conflict) ──────────────────────

  /// Combined pre-flight for "new booking" / "new open match" flows.
  /// Throws `court-occupied` or `schedule-conflict` so callers can
  /// show the right message.
  Future<void> assertNoConflictForNewReservation({
    required String userId,
    required String courtId,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    if (await isCourtOccupied(
      courtId: courtId,
      date: date,
      startTime: startTime,
      endTime: endTime,
    )) {
      throw StateError('court-occupied');
    }
    if (await hasUserConflict(
      userId: userId,
      date: date,
      startTime: startTime,
      endTime: endTime,
    )) {
      throw StateError('schedule-conflict');
    }
  }

  /// For "join existing match" / "accept invite" — the court is
  /// already booked by the host's match, so only the user's own
  /// schedule needs checking.
  Future<void> assertNoUserConflict({
    required String userId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? excludeMatchId,
  }) async {
    if (await hasUserConflict(
      userId: userId,
      date: date,
      startTime: startTime,
      endTime: endTime,
      excludeMatchId: excludeMatchId,
    )) {
      throw StateError('schedule-conflict');
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
