import 'package:flutter/material.dart';

/// Single source of truth for the generated 1-hour time slots offered
/// to users when they book a court. Lives here (not inside the Book
/// Court overlay) so the same constant powers two surfaces:
///
///   * The Book Court overlay's time-slot grid.
///   * The court card's top-left "X slots today" badge.
///
/// Per-slot availability (i.e. which slots are already booked) is
/// deferred to a later phase; today every slot is selectable, and the
/// badge says "7 slots today" because there are seven generated slots.
class BookingSlot {
  final String start;
  final String end;

  const BookingSlot({required this.start, required this.end});

  /// Render `06:00` / `18:00` as `6:00 AM` / `6:00 PM` using the
  /// platform's `MaterialLocalizations` so the system's 12/24-hour
  /// preference is honoured.
  String label(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String fmt(String hhmm) {
      final parts = hhmm.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return localizations.formatTimeOfDay(TimeOfDay(hour: h, minute: m));
    }

    return '${fmt(start)} - ${fmt(end)}';
  }
}

const List<BookingSlot> bookingSlots = [
  BookingSlot(start: '06:00', end: '07:00'),
  BookingSlot(start: '07:00', end: '08:00'),
  BookingSlot(start: '08:00', end: '09:00'),
  BookingSlot(start: '17:00', end: '18:00'),
  BookingSlot(start: '18:00', end: '19:00'),
  BookingSlot(start: '19:00', end: '20:00'),
  BookingSlot(start: '20:00', end: '21:00'),
];
