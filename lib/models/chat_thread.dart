import 'package:cloud_firestore/cloud_firestore.dart';

/// `threads/{threadId}`. Two shapes:
///   * [typeDirect] — 1-to-1 chat. `participantIds` has exactly two
///     uids.
///   * [typeGroup] — open-match group chat. `participantIds` grows
///     as players join. Carries extra snapshot fields (`matchId`,
///     `title`, `imageUrl`, `sportType`, `courtName`) so the threads
///     list renders without a per-card match lookup.
///
/// Legacy docs without a `type` field are treated as direct.
class ChatThread {
  static const String typeDirect = 'direct';
  static const String typeGroup = 'group';

  final String id;
  final String type;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Per-uid "last time this user opened the chat." A null entry
  /// (including the brief server-timestamp resolution window) reads
  /// as "never read", which keeps the unread indicator from
  /// flashing off.
  final Map<String, DateTime> lastReadAtByUser;

  /// Group-only metadata. `null` on direct threads.
  final String? matchId;
  final String? title;
  final String? imageUrl;
  final String? sportType;
  final String? courtName;

  const ChatThread({
    required this.id,
    required this.type,
    required this.participantIds,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.lastSenderId,
    required this.createdAt,
    required this.updatedAt,
    this.lastReadAtByUser = const {},
    this.matchId,
    this.title,
    this.imageUrl,
    this.sportType,
    this.courtName,
  });

  bool get isDirect => type == typeDirect;
  bool get isGroup => type == typeGroup;

  /// The other participant in a 1-to-1 thread. Meaningless for group
  /// threads — callers should branch on [isGroup] first.
  String? otherParticipant(String currentUid) {
    for (final id in participantIds) {
      if (id != currentUid) return id;
    }
    return null;
  }

  DateTime? lastReadAtFor(String uid) => lastReadAtByUser[uid];

  /// Unread for [uid] when there's a message, the sender isn't [uid],
  /// and [uid] hasn't opened the thread since that message landed.
  /// "Strictly before" matters — opening the chat writes a fresh
  /// timestamp ≥ the latest message, so the thread flips to read.
  bool isUnreadFor(String uid) {
    final lastAt = lastMessageAt;
    if (lastAt == null) return false;
    if (lastSenderId == uid) return false;
    final readAt = lastReadAtByUser[uid];
    if (readAt == null) return true;
    return readAt.isBefore(lastAt);
  }

  factory ChatThread.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ids =
        (data['participantIds'] as List<dynamic>?)?.cast<String>() ??
        const <String>[];
    // Legacy docs without a `type` are direct.
    final type = (data['type'] as String?) ?? typeDirect;
    return ChatThread(
      id: doc.id,
      type: type,
      participantIds: ids,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastSenderId: data['lastSenderId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastReadAtByUser: _parseReadMap(data['lastReadAtByUser']),
      matchId: data['matchId'] as String?,
      title: data['title'] as String?,
      imageUrl: data['imageUrl'] as String?,
      sportType: data['sportType'] as String?,
      courtName: data['courtName'] as String?,
    );
  }

  /// Tolerates missing field (legacy docs) and malformed entries —
  /// anything that isn't a Timestamp under a String key is ignored.
  static Map<String, DateTime> _parseReadMap(dynamic raw) {
    if (raw is! Map) return const {};
    final result = <String, DateTime>{};
    raw.forEach((key, value) {
      if (key is String && value is Timestamp) {
        result[key] = value.toDate();
      }
    });
    return result;
  }
}
