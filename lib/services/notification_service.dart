import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

/// Reads + writes `notifications/{id}`. Every query is single-field
/// equality on `userId` and sorted client-side, so we don't ship a
/// composite `userId + createdAt` index. Per-user volume stays small
/// (tens to low hundreds), so client-sort is cheap.
class NotificationService {
  final FirebaseFirestore _db;

  NotificationService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  /// Newest first. A freshly-written notification's `createdAt` is
  /// briefly null while the server stamp settles — we treat null as
  /// "now" so the new row stays at the top until the server confirms.
  Stream<List<AppNotification>> streamNotificationsForUser(String userId) {
    return _notifications.where('userId', isEqualTo: userId).snapshots().map((
      snap,
    ) {
      final list = snap.docs
          .map((doc) => AppNotification.fromDoc(doc))
          .toList();
      list.sort((a, b) {
        final aT = a.createdAt ?? DateTime.now();
        final bT = b.createdAt ?? DateTime.now();
        return bT.compareTo(aT);
      });
      return list;
    });
  }

  Stream<int> streamUnreadCount(String userId) {
    return _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Append one notification. Callers should fire-and-forget through
  /// try/catch so a Firestore rules / network blip never blocks the
  /// originating action (booking, invite, …).
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? targetType,
    String? targetId,
  }) async {
    await _notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'targetType': targetType,
      'targetId': targetId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _notifications.doc(notificationId).update({'isRead': true});
  }

  /// Bulk mark-read in a single batch so the unread badge drops to
  /// zero in one snapshot instead of flickering down row by row.
  Future<void> markAllAsRead(String userId) async {
    final unread = await _notifications
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
