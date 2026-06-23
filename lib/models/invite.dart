import 'package:cloud_firestore/cloud_firestore.dart';

/// `invites/{inviteId}`.
///
/// Carries pinned snapshots of both users + court + time so an
/// invite card renders without extra reads on `users/{uid}` or
/// `open_matches/{matchId}`. The open match remains the source of
/// truth for live counts — these snapshots are backstop copy.
///
/// Status lifecycle:
///   * `pending`   — invitee can accept or decline.
///   * `accepted`  — invitee accepted; joinOpenMatch transaction
///                   added them to `joinedPlayerIds`.
///   * `declined`  — invitee declined.
///   * `cancelled` — host cancelled the underlying match.
class Invite {
  static const String statusPending = 'pending';
  static const String statusAccepted = 'accepted';
  static const String statusDeclined = 'declined';
  static const String statusCancelled = 'cancelled';

  final String id;

  final String matchId;

  final String fromUserId;
  final String fromUserName;
  final String fromUserInitials;
  final String? fromUserPhotoUrl;
  final String? fromUserAvatarId;

  final String toUserId;
  final String toUserName;
  final String toUserInitials;
  final String? toUserPhotoUrl;
  final String? toUserAvatarId;

  final String courtId;
  final String courtName;
  final String courtAddress;
  final String courtImageUrl;

  final String sportType;
  final DateTime date;

  /// 24-hour `HH:mm`.
  final String startTime;
  final String endTime;

  final int playersRequired;

  /// Snapshot of `OpenMatch.effectiveJoinedCount` at create time.
  /// Backstop only — the live count comes from the match doc.
  final int effectiveJoinedCountAtSend;

  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invite({
    required this.id,
    required this.matchId,
    required this.fromUserId,
    required this.fromUserName,
    required this.fromUserInitials,
    required this.fromUserPhotoUrl,
    required this.fromUserAvatarId,
    required this.toUserId,
    required this.toUserName,
    required this.toUserInitials,
    required this.toUserPhotoUrl,
    required this.toUserAvatarId,
    required this.courtId,
    required this.courtName,
    required this.courtAddress,
    required this.courtImageUrl,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.playersRequired,
    required this.effectiveJoinedCountAtSend,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == statusPending;
  bool get isAccepted => status == statusAccepted;
  bool get isDeclined => status == statusDeclined;
  bool get isCancelled => status == statusCancelled;

  Invite copyWith({String? status, DateTime? updatedAt}) {
    return Invite(
      id: id,
      matchId: matchId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      fromUserInitials: fromUserInitials,
      fromUserPhotoUrl: fromUserPhotoUrl,
      fromUserAvatarId: fromUserAvatarId,
      toUserId: toUserId,
      toUserName: toUserName,
      toUserInitials: toUserInitials,
      toUserPhotoUrl: toUserPhotoUrl,
      toUserAvatarId: toUserAvatarId,
      courtId: courtId,
      courtName: courtName,
      courtAddress: courtAddress,
      courtImageUrl: courtImageUrl,
      sportType: sportType,
      date: date,
      startTime: startTime,
      endTime: endTime,
      playersRequired: playersRequired,
      effectiveJoinedCountAtSend: effectiveJoinedCountAtSend,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'matchId': matchId,
    'fromUserId': fromUserId,
    'fromUserName': fromUserName,
    'fromUserInitials': fromUserInitials,
    'fromUserPhotoUrl': fromUserPhotoUrl,
    'fromUserAvatarId': fromUserAvatarId,
    'toUserId': toUserId,
    'toUserName': toUserName,
    'toUserInitials': toUserInitials,
    'toUserPhotoUrl': toUserPhotoUrl,
    'toUserAvatarId': toUserAvatarId,
    'courtId': courtId,
    'courtName': courtName,
    'courtAddress': courtAddress,
    'courtImageUrl': courtImageUrl,
    'sportType': sportType,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'playersRequired': playersRequired,
    'effectiveJoinedCountAtSend': effectiveJoinedCountAtSend,
    'status': status,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
  };

  factory Invite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Invite.fromMap({...data, 'id': doc.id});
  }

  factory Invite.fromMap(Map<String, dynamic> map) {
    return Invite(
      id: (map['id'] as String?) ?? '',
      matchId: (map['matchId'] as String?) ?? '',
      fromUserId: (map['fromUserId'] as String?) ?? '',
      fromUserName: (map['fromUserName'] as String?) ?? '',
      fromUserInitials: (map['fromUserInitials'] as String?) ?? '?',
      fromUserPhotoUrl: map['fromUserPhotoUrl'] as String?,
      fromUserAvatarId: map['fromUserAvatarId'] as String?,
      toUserId: (map['toUserId'] as String?) ?? '',
      toUserName: (map['toUserName'] as String?) ?? '',
      toUserInitials: (map['toUserInitials'] as String?) ?? '?',
      toUserPhotoUrl: map['toUserPhotoUrl'] as String?,
      toUserAvatarId: map['toUserAvatarId'] as String?,
      courtId: (map['courtId'] as String?) ?? '',
      courtName: (map['courtName'] as String?) ?? '',
      courtAddress: (map['courtAddress'] as String?) ?? '',
      courtImageUrl: (map['courtImageUrl'] as String?) ?? '',
      sportType: (map['sportType'] as String?) ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (map['startTime'] as String?) ?? '',
      endTime: (map['endTime'] as String?) ?? '',
      playersRequired: _parseInt(map['playersRequired']) ?? 0,
      effectiveJoinedCountAtSend:
          _parseInt(map['effectiveJoinedCountAtSend']) ?? 0,
      // Missing status defaults to pending — a half-written doc must
      // not silently land in a terminal state.
      status: (map['status'] as String?) ?? Invite.statusPending,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }
}
