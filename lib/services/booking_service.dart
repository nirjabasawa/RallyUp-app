import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/app_notification.dart';
import '../models/booking.dart';
import '../models/court.dart';
import 'notification_service.dart';
import 'schedule_conflict_service.dart';

/// Firestore layer for `bookings/{id}` (private court reservations).
class BookingService {
  final FirebaseFirestore _db;
  final NotificationService _notifications;
  final ScheduleConflictService _conflicts;

  BookingService({
    FirebaseFirestore? db,
    NotificationService? notifications,
    ScheduleConflictService? conflicts,
  }) : _db = db ?? FirebaseFirestore.instance,
       _notifications = notifications ?? NotificationService(),
       _conflicts =
           conflicts ??
           ScheduleConflictService(db: db ?? FirebaseFirestore.instance);

  CollectionReference<Map<String, dynamic>> get _bookings =>
      _db.collection('bookings');

  /// Every booking belonging to [userId], sorted by date + start
  /// time. Sort happens client-side to avoid a composite index on
  /// `userId + date`.
  Stream<List<Booking>> streamBookingsForUser(String userId) {
    return _bookings.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final bookings = snap.docs.map((doc) => Booking.fromDoc(doc)).toList();
      bookings.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.startTime.compareTo(b.startTime);
      });
      return bookings;
    });
  }

  /// Persist a confirmed booking.
  ///
  /// Snapshot fields (`courtName`, `courtAddress`, `courtImageUrl`,
  /// `pricePerHour`) are baked into the doc at write time so list /
  /// detail views render without a follow-up `courts/{id}` read, and
  /// so a later rename of the court can't rewrite history.
  ///
  /// `totalPrice == pricePerHour` for now because every slot is one
  /// hour. When variable-length bookings ship, multiply by hours.
  Future<Booking> createBooking({
    required String userId,
    required Court court,
    required String sportType,
    required DateTime date,
    required String startTime,
    required String endTime,
  }) async {
    await _conflicts.assertNoConflictForNewReservation(
      userId: userId,
      courtId: court.id,
      date: date,
      startTime: startTime,
      endTime: endTime,
    );

    final ref = _bookings.doc();
    final now = DateTime.now();
    final courtImageUrl = court.imageUrls.isNotEmpty
        ? court.imageUrls.first
        : '';

    final payload = {
      'userId': userId,
      'courtId': court.id,
      'courtName': court.name,
      'courtAddress': court.address,
      'courtImageUrl': courtImageUrl,
      'sportType': sportType,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'pricePerHour': court.pricePerHour,
      'totalPrice': court.pricePerHour,
      'status': BookingStatus.confirmed,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await ref.set(payload);

    _safeNotify(
      userId: userId,
      title: 'Court booked',
      body:
          '${court.name} is booked for ${_humanWhen(date, startTime, endTime)}.',
      type: AppNotification.typeBookingConfirmed,
      targetType: AppNotification.targetBooking,
      targetId: ref.id,
    );

    // Return a hydrated model so the caller can route straight into
    // BookingConfirmedPage. createdAt/updatedAt are client-clock
    // estimates; the next stream snapshot replaces them with the
    // server values.
    return Booking(
      id: ref.id,
      userId: userId,
      courtId: court.id,
      courtName: court.name,
      courtAddress: court.address,
      courtImageUrl: courtImageUrl,
      sportType: sportType,
      date: date,
      startTime: startTime,
      endTime: endTime,
      pricePerHour: court.pricePerHour,
      totalPrice: court.pricePerHour,
      status: BookingStatus.confirmed,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<Booking?> getBooking(String bookingId) async {
    final snap = await _bookings.doc(bookingId).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return Booking.fromMap({...data, 'id': snap.id});
  }

  /// Soft cancel — flip the status, keep the doc. Past bookings stay
  /// visible in MyBookings under their Cancelled tag.
  Future<void> cancelBooking(String bookingId) async {
    await _bookings.doc(bookingId).update({
      'status': BookingStatus.cancelled,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      final booking = await getBooking(bookingId);
      if (booking != null) {
        _safeNotify(
          userId: booking.userId,
          title: 'Booking cancelled',
          body: '${booking.courtName} was cancelled.',
          type: AppNotification.typeBookingCancelled,
          targetType: AppNotification.targetBooking,
          targetId: booking.id,
        );
      }
    } catch (e) {
      debugPrint('BookingService: cancellation notification skipped: $e');
    }
  }

  /// Fire-and-forget notification. Swallows errors so a Firestore
  /// rules / network blip on `notifications` can never cascade into
  /// a booking write failure.
  void _safeNotify({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? targetType,
    String? targetId,
  }) {
    _notifications
        .createNotification(
          userId: userId,
          title: title,
          body: body,
          type: type,
          targetType: targetType,
          targetId: targetId,
        )
        .catchError((e) {
          debugPrint('BookingService: notification write failed: $e');
        });
  }

  String _humanWhen(DateTime date, String startTime, String endTime) {
    final d = DateFormat('EEE, MMM d').format(date);
    return '$d · $startTime - $endTime';
  }
}
