import 'package:cloud_firestore/cloud_firestore.dart';

/// `threads/{threadId}/messages/{messageId}`.
///
/// Intentionally narrow: sender + text + sentAt. Read receipts,
/// delivery status, media, reactions — all deferred.
///
/// [senderName] is a send-time snapshot used by group bubbles to
/// label messages without a per-message `users/{uid}` read. Direct
/// chats don't need it (the other user is resolved at thread-open
/// time); older direct messages may not have written it.
class ChatMessage {
  final String id;
  final String senderUid;
  final String? senderName;
  final String text;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.senderUid,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  Map<String, dynamic> toMap() => {
    'senderUid': senderUid,
    if (senderName != null) 'senderName': senderName,
    'text': text,
    'sentAt': Timestamp.fromDate(sentAt),
  };

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return ChatMessage(
      id: doc.id,
      senderUid: (data['senderUid'] as String?) ?? '',
      senderName: data['senderName'] as String?,
      text: (data['text'] as String?) ?? '',
      // Server timestamp is briefly null on the writing client.
      // Fall back to now() so ordering stays sensible.
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
