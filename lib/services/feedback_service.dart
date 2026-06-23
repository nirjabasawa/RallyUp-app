import 'package:cloud_firestore/cloud_firestore.dart';

/// Writes to `feedback/{id}` and `reports/{id}`.
///
/// ```
/// feedback/{id}
///   userId?, userEmail?, userName?  (null for anonymous)
///   category, message, createdAt
///
/// reports/{id}
///   reporterId, reporterName, reportedUserId, reportedUserName,
///   reason, status: 'open' | 'reviewed' | 'dismissed', createdAt
/// ```
///
/// Errors propagate — the calling screen surfaces a SnackBar.
class FeedbackService {
  final FirebaseFirestore _db;

  FeedbackService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _feedback =>
      _db.collection('feedback');

  CollectionReference<Map<String, dynamic>> get _reports =>
      _db.collection('reports');

  /// Validates non-empty server-side as a backstop against a
  /// misbehaving caller.
  Future<void> submitFeedback({
    required String message,
    String category = 'Feedback',
    String? userId,
    String? userEmail,
    String? userName,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Feedback message cannot be empty.');
    }
    await _feedback.add({
      'userId': userId,
      'userEmail': userEmail,
      'userName': userName,
      'category': category.trim().isEmpty ? 'Feedback' : category.trim(),
      'message': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// New reports start as `status: open`. Moderator review is
  /// future work.
  Future<void> reportUser({
    required String reporterId,
    required String reporterName,
    required String reportedUserId,
    required String reportedUserName,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      throw ArgumentError('Report reason cannot be empty.');
    }
    await _reports.add({
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportedUserId': reportedUserId,
      'reportedUserName': reportedUserName,
      'reason': trimmedReason,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
