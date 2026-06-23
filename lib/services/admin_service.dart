import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/id_verification.dart';

/// In-app moderator surface.
///
/// Gating is intentionally minimal — a hardcoded allow-list of admin
/// emails plus a UI check on the drawer entry. Server-side rules
/// enforcement is future work; this service just makes the writes
/// the reviewer needs and trusts the caller.
///
/// To promote an account to admin, add their email to [_adminEmails]
/// and they'll see "ID Verification Reviews" in the side drawer
/// after the next sign-in.
class AdminService {
  static const Set<String> _adminEmails = {'allurkars25@gmail.com'};

  final FirebaseFirestore _db;

  AdminService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Email-only, case-insensitive.
  bool isAdmin(AppUser? user) {
    final email = user?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;
    return _adminEmails.any((e) => e.toLowerCase() == email);
  }

  Stream<List<AppUser>> streamPendingIdVerifications() {
    return _users
        .where('idVerification.status', isEqualTo: 'submitted')
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => AppUser.fromMap({...doc.data(), 'uid': doc.id}))
              .toList();
        });
  }

  /// Flip a submitted record to a terminal status. The initial
  /// `submitted` state belongs to the user-submit flow, not here.
  Future<void> setVerificationStatus({
    required String userId,
    required IdVerificationStatus status,
    String? reviewerNote,
  }) async {
    if (status == IdVerificationStatus.submitted) {
      throw ArgumentError(
        'setVerificationStatus only takes verified / rejected.',
      );
    }
    final payload = <String, dynamic>{
      'idVerification.status': status.storageKey,
      'idVerification.reviewedAt': FieldValue.serverTimestamp(),
    };
    if (reviewerNote != null && reviewerNote.trim().isNotEmpty) {
      payload['idVerification.reviewerNote'] = reviewerNote.trim();
    }
    await _users.doc(userId).update(payload);
  }
}
