import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_thread.dart';
import '../models/open_match.dart';

/// Direct (1-to-1) and open-match group messaging share one
/// `threads/{threadId}` collection so the send/read APIs and preview
/// fields stay symmetrical.
///
/// ```
/// threads/{threadId}
///   type:             'direct' | 'group'   (missing → 'direct')
///   participantIds:   [uid, uid, …]
///   lastMessage:      string?
///   lastMessageAt:    Timestamp?
///   lastSenderId:     string?
///   createdAt, updatedAt: Timestamp
///   lastReadAtByUser: { uid: Timestamp }
///   // group-only:
///   matchId, title, imageUrl, sportType, courtName
///
/// threads/{threadId}/messages/{messageId}
///   senderUid, senderName?, text, sentAt
/// ```
///
/// Thread ids are deterministic. Direct: the two uids sorted and
/// joined with `_`. Group: `match_<matchId>`. Either form lets the
/// caller jump to a doc by id with no `where(...)` lookup.
class ChatService {
  final FirebaseFirestore _db;

  ChatService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _threads =>
      _db.collection('threads');

  // ─── Direct threads ─────────────────────────────────────────────

  String directThreadId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return ids.join('_');
  }

  /// Returns the existing thread id between [currentUid] and
  /// [otherUid], creating the parent doc on the first call.
  /// Idempotent — repeated calls return the same id and merge
  /// without overwriting metadata.
  Future<String> createOrGetDirectThread({
    required String currentUid,
    required String otherUid,
  }) async {
    final id = directThreadId(currentUid, otherUid);
    final ref = _threads.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      final now = FieldValue.serverTimestamp();
      await ref.set({
        'type': ChatThread.typeDirect,
        'participantIds': [currentUid, otherUid]..sort(),
        'lastMessage': null,
        'lastMessageAt': null,
        'lastSenderId': null,
        'createdAt': now,
        'updatedAt': now,
      });
    }
    return id;
  }

  // ─── Group (open-match) threads ─────────────────────────────────

  /// `match_` prefix guarantees no collision with a direct id even if
  /// a uid ever contained an underscore.
  String groupThreadIdForMatch(String matchId) => 'match_$matchId';

  /// Create or refresh the group thread for [match]. Safe to call
  /// on every match create/join because the write is `merge: true`
  /// with a deterministic id.
  ///
  /// Participants are always merged via `arrayUnion` on existing
  /// threads — a stale local OpenMatch snapshot must never silently
  /// drop a remote joiner. Removals go through
  /// [removeUserFromGroupThread] only.
  Future<void> createOrUpdateGroupThreadForMatch(OpenMatch match) async {
    final id = groupThreadIdForMatch(match.id);
    final ref = _threads.doc(id);
    final snap = await ref.get();
    final title = '${match.sportType} at ${match.courtName}'.trim();
    final imageUrl = match.courtImageUrl;
    final now = FieldValue.serverTimestamp();

    final base = <String, dynamic>{
      'type': ChatThread.typeGroup,
      'matchId': match.id,
      'title': title,
      'imageUrl': imageUrl,
      'sportType': match.sportType,
      'courtName': match.courtName,
      'updatedAt': now,
    };
    if (!snap.exists) {
      base['participantIds'] = List<String>.from(match.joinedPlayerIds);
      base['lastMessage'] = null;
      base['lastMessageAt'] = null;
      base['lastSenderId'] = null;
      base['createdAt'] = now;
    } else {
      base['participantIds'] = FieldValue.arrayUnion(
        List<String>.from(match.joinedPlayerIds),
      );
    }
    await ref.set(base, SetOptions(merge: true));
  }

  /// Idempotent — `arrayUnion` so a join → leave → join sequence
  /// doesn't duplicate the uid. Court snapshots get refreshed in case
  /// the host moved the match between updates.
  Future<void> addUserToGroupThread({
    required OpenMatch match,
    required AppUser user,
  }) async {
    final id = groupThreadIdForMatch(match.id);
    final ref = _threads.doc(id);
    final now = FieldValue.serverTimestamp();
    final title = '${match.sportType} at ${match.courtName}'.trim();
    await ref.set({
      'type': ChatThread.typeGroup,
      'matchId': match.id,
      'title': title,
      'imageUrl': match.courtImageUrl,
      'sportType': match.sportType,
      'courtName': match.courtName,
      'participantIds': FieldValue.arrayUnion([user.uid]),
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Remove [userId] from the thread's participants without deleting
  /// the chat history — other members can still scroll back.
  Future<void> removeUserFromGroupThread({
    required OpenMatch match,
    required String userId,
  }) async {
    final id = groupThreadIdForMatch(match.id);
    final ref = _threads.doc(id);
    await ref.set({
      'participantIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ChatThread>> streamGroupThreadsForUser(String uid) {
    return _threads.where('participantIds', arrayContains: uid).snapshots().map(
      (snap) {
        final threads = snap.docs
            .map((doc) => ChatThread.fromDoc(doc))
            .where((t) => t.isGroup)
            .toList();
        threads.sort((a, b) {
          final aT = a.lastMessageAt ?? a.updatedAt;
          final bT = b.lastMessageAt ?? b.updatedAt;
          return bT.compareTo(aT);
        });
        return threads;
      },
    );
  }

  // ─── Messages (shared by direct + group) ────────────────────────

  /// Oldest-first; MessagePage uses `reverse: true` on its ListView.
  Stream<List<ChatMessage>> streamMessages(String threadId) {
    return _threads
        .doc(threadId)
        .collection('messages')
        .orderBy('sentAt')
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) => ChatMessage.fromDoc(doc)).toList(),
        );
  }

  /// Writes the message and bumps the parent thread's preview fields
  /// in the same batch so the threads list updates atomically.
  ///
  /// The sender's own `lastReadAtByUser` entry is bumped to the
  /// message timestamp — that's what keeps the thread "read" for the
  /// sender while leaving every other participant unread. We never
  /// touch other participants' read timestamps here; theirs only
  /// advance through [markThreadRead] when they open the chat.
  ///
  /// [senderName] lets group bubbles label messages without a
  /// per-message `users/{uid}` lookup. Direct chats can leave it null.
  Future<void> sendMessage({
    required String threadId,
    required String senderUid,
    required String text,
    String? senderName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final threadRef = _threads.doc(threadId);
    final messageRef = threadRef.collection('messages').doc();
    final now = FieldValue.serverTimestamp();

    final messagePayload = <String, dynamic>{
      'senderUid': senderUid,
      'text': trimmed,
      'sentAt': now,
    };
    if (senderName != null && senderName.isNotEmpty) {
      messagePayload['senderName'] = senderName;
    }

    final batch = _db.batch();
    batch.set(messageRef, messagePayload);
    // `set(merge)` instead of `update` so a missing parent doc gets
    // (re)created instead of throwing. The nested `lastReadAtByUser`
    // map deep-merges, so only the sender's entry is touched.
    batch.set(threadRef, {
      'lastMessage': trimmed,
      'lastMessageAt': now,
      'lastSenderId': senderUid,
      'updatedAt': now,
      'lastReadAtByUser': {senderUid: now},
    }, SetOptions(merge: true));
    await batch.commit();
  }

  /// Bumps [uid]'s read marker to "now". Idempotent and safe to call
  /// repeatedly. `set(merge: true)` rather than `update` so a stale
  /// or just-created parent doc never throws.
  Future<void> markThreadRead({
    required String threadId,
    required String uid,
  }) async {
    await _threads.doc(threadId).set({
      'lastReadAtByUser': {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  Future<ChatThread?> getThread(String threadId) async {
    final snap = await _threads.doc(threadId).get();
    if (!snap.exists) return null;
    return ChatThread.fromDoc(snap);
  }

  // ─── Thread streams (per shape) ─────────────────────────────────

  /// Direct threads only, newest-activity first. Group threads are
  /// filtered out client-side so the legacy Messages tab stays
  /// 1-to-1.
  ///
  /// Sorting is client-side rather than via Firestore `orderBy`
  /// because combining `arrayContains` with `orderBy` requires a
  /// composite index, and because `updatedAt` is a server timestamp
  /// that briefly resolves to null on the writing client — a server
  /// sort would hide brand-new threads from the sender until the
  /// server confirms.
  Stream<List<ChatThread>> streamThreadsForUser(String uid) {
    return _threads.where('participantIds', arrayContains: uid).snapshots().map(
      (snap) {
        final threads = snap.docs
            .map((doc) => ChatThread.fromDoc(doc))
            .where((t) => t.isDirect)
            .toList();
        threads.sort((a, b) {
          final aT = a.lastMessageAt ?? a.updatedAt;
          final bT = b.lastMessageAt ?? b.updatedAt;
          return bT.compareTo(aT);
        });
        return threads;
      },
    );
  }
}
