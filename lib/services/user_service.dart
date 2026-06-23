import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _db;

  UserService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;
    return AppUser.fromMap({...data, 'uid': uid});
  }

  /// `extras` is merged after `user.toMap()` so callers can write
  /// Firestore-only shadow fields (e.g. flattened location columns
  /// for future geo queries) without polluting the AppUser model.
  Future<void> createUser(
    AppUser user, {
    Map<String, dynamic> extras = const {},
  }) async {
    await _users.doc(user.uid).set({...user.toMap(), ...extras});
  }

  Future<void> updateFields(String uid, Map<String, dynamic> fields) async {
    final payload = {
      ...fields,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
    await _users.doc(uid).update(payload);
  }

  Future<void> deleteUser(String uid) async {
    await _users.doc(uid).delete();
  }

  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      return AppUser.fromMap({...data, 'uid': uid});
    });
  }

  /// Every discoverable user. Drops [excludeUid] (the caller) and
  /// anyone with `profileVisible == false`. Used by Nearby Players.
  /// Future work: geo-bounded query once user scale grows.
  Stream<List<AppUser>> streamAllUsers({String? excludeUid}) {
    return _users.snapshots().map((snap) {
      return snap.docs
          .map((doc) => AppUser.fromMap({...doc.data(), 'uid': doc.id}))
          .where((u) {
            if (excludeUid != null && u.uid == excludeUid) return false;
            return u.profileVisible;
          })
          .toList();
    });
  }
}
