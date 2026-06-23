import 'package:cloud_firestore/cloud_firestore.dart';

/// String constants rather than an enum so a future server-added
/// status (e.g. 'completed') doesn't crash the client.
class BookingStatus {
  static const String confirmed = 'confirmed';
  static const String cancelled = 'cancelled';
}

/// `bookings/{id}`. Carries a small court snapshot so list rendering
/// doesn't need a per-row `courts/{courtId}` lookup.
class Booking {
  final String id;
  final String userId;
  final String courtId;
  final String courtName;
  final String courtAddress;

  /// First court image at booking time. May be empty.
  final String courtImageUrl;
  final String sportType;
  final DateTime date;

  /// 24-hour `HH:mm`. 12-hour display formatting is the caller's job.
  final String startTime;
  final String endTime;
  final double pricePerHour;
  final double totalPrice;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.courtId,
    required this.courtName,
    required this.courtAddress,
    required this.courtImageUrl,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isConfirmed => status == BookingStatus.confirmed;
  bool get isCancelled => status == BookingStatus.cancelled;

  Booking copyWith({String? status, DateTime? updatedAt}) {
    return Booking(
      id: id,
      userId: userId,
      courtId: courtId,
      courtName: courtName,
      courtAddress: courtAddress,
      courtImageUrl: courtImageUrl,
      sportType: sportType,
      date: date,
      startTime: startTime,
      endTime: endTime,
      pricePerHour: pricePerHour,
      totalPrice: totalPrice,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'courtId': courtId,
    'courtName': courtName,
    'courtAddress': courtAddress,
    'courtImageUrl': courtImageUrl,
    'sportType': sportType,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'pricePerHour': pricePerHour,
    'totalPrice': totalPrice,
    'status': status,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
  };

  factory Booking.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Booking.fromMap({...data, 'id': doc.id});
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: (map['id'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      courtId: (map['courtId'] as String?) ?? '',
      courtName: (map['courtName'] as String?) ?? '',
      courtAddress: (map['courtAddress'] as String?) ?? '',
      courtImageUrl: (map['courtImageUrl'] as String?) ?? '',
      sportType: (map['sportType'] as String?) ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (map['startTime'] as String?) ?? '',
      endTime: (map['endTime'] as String?) ?? '',
      pricePerHour: _parseDouble(map['pricePerHour']) ?? 0,
      totalPrice: _parseDouble(map['totalPrice']) ?? 0,
      // Missing status → confirmed. A partial write is far more
      // likely than a cancellation that lost its field.
      status: (map['status'] as String?) ?? BookingStatus.confirmed,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static double? _parseDouble(dynamic raw) {
    if (raw == null) return null;
    if (raw is double) return raw;
    if (raw is int) return raw.toDouble();
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }
}
