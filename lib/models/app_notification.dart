import 'package:cloud_firestore/cloud_firestore.dart';

/// `notifications/{id}`. Per-event records keyed by `userId`. The
/// push Cloud Function reads the same fields server-side.
///
/// `type` is a string (not an enum) so a server process can
/// introduce a new event without forcing a client migration.
/// `targetType` + `targetId` are untyped pointers — the client
/// resolves them at tap time, avoiding embedded snapshots.
class AppNotification {
  static const String typeBookingConfirmed = 'booking_confirmed';
  static const String typeBookingCancelled = 'booking_cancelled';
  static const String typeInviteReceived = 'invite_received';
  static const String typeInviteAccepted = 'invite_accepted';
  static const String typeInviteDeclined = 'invite_declined';
  static const String typeOpenMatchCreated = 'open_match_created';
  static const String typeMatchJoined = 'match_joined';
  static const String typeMatchLeft = 'match_left';
  static const String typeOpenMatchCancelled = 'open_match_cancelled';
  static const String typeSystem = 'system';

  static const String targetBooking = 'booking';
  static const String targetInvite = 'invite';
  static const String targetMatch = 'match';

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final String? targetType;
  final String? targetId;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.targetType,
    required this.targetId,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      type: type,
      targetType: targetType,
      targetId: targetId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'title': title,
    'body': body,
    'type': type,
    'targetType': targetType,
    'targetId': targetId,
    'isRead': isRead,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
  };

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppNotification.fromMap({...data, 'id': doc.id});
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: (map['id'] as String?) ?? '',
      userId: (map['userId'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      type: (map['type'] as String?) ?? AppNotification.typeSystem,
      targetType: map['targetType'] as String?,
      targetId: map['targetId'] as String?,
      // Missing isRead → unread; never silently mark a new
      // server-written notification as already seen.
      isRead: (map['isRead'] as bool?) ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
