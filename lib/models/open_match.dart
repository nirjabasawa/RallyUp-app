import 'package:cloud_firestore/cloud_firestore.dart';

/// `open_matches/{matchId}`.
///
/// Carries a small host snapshot so list cards render without a
/// follow-up `users/{hostUid}` read, and so a later rename of the
/// host doesn't retroactively rewrite every match they ever hosted.
///
/// Joined players are two parallel string arrays (uid + display
/// name) rather than a list of maps — arrays of primitives play well
/// with `arrayUnion` and Firestore rules. Per-player metadata
/// (avatarId, photoUrl, joinedAt, …) would move to a subcollection.
///
/// [confirmedGuestCount] is the host's offline-confirmed players —
/// no real uid, but counted toward [effectiveJoinedCount].
class OpenMatch {
  static const String statusOpen = 'open';
  static const String statusFull = 'full';
  static const String statusCancelled = 'cancelled';

  final String id;

  final String hostUid;
  final String hostName;
  final String hostInitials;
  final String? hostPhotoUrl;
  final String? hostAvatarId;

  final String courtId;
  final String courtName;
  final String courtAddress;

  /// First image — kept for backward compatibility and for list
  /// cards / the home rail that only need a single thumbnail.
  final String courtImageUrl;

  /// Full carousel set. Old docs without this field fall back to
  /// `[courtImageUrl]`.
  final List<String> courtImageUrls;

  final String sportType;
  final DateTime date;

  /// 24-hour `HH:mm`.
  final String startTime;
  final String endTime;
  final double pricePerHour;
  final double totalPrice;

  final int playersRequired;
  final List<String> joinedPlayerIds;
  final List<String> joinedPlayerNames;

  /// Host-claimed offline players. They have no [joinedPlayerIds]
  /// entry but count toward capacity. Equals `playersConfirmed - 1`
  /// at create time (subtracting the host themselves).
  final int confirmedGuestCount;

  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const OpenMatch({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.hostInitials,
    required this.hostPhotoUrl,
    required this.hostAvatarId,
    required this.courtId,
    required this.courtName,
    required this.courtAddress,
    required this.courtImageUrl,
    required this.courtImageUrls,
    required this.sportType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.pricePerHour,
    required this.totalPrice,
    required this.playersRequired,
    required this.joinedPlayerIds,
    required this.joinedPlayerNames,
    required this.confirmedGuestCount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Real uids. Use for DM, profile lookup, dedupe, transactions.
  int get realJoinedCount => joinedPlayerIds.length;

  /// Real users + offline-confirmed guests. Use for any user-facing
  /// count or capacity check.
  int get effectiveJoinedCount => joinedPlayerIds.length + confirmedGuestCount;

  /// Alias kept so existing cards and labels pick up the effective
  /// count without a renaming sweep. Prefer [effectiveJoinedCount]
  /// in new code.
  int get joinedCount => effectiveJoinedCount;

  int get spotsLeft {
    final left = playersRequired - effectiveJoinedCount;
    return left < 0 ? 0 : left;
  }

  bool get isOpen => status == statusOpen;
  bool get isFull => status == statusFull;
  bool get isCancelled => status == statusCancelled;

  /// Guards against `playersRequired == 0` from a hand-edited doc.
  double get pricePerPlayer {
    final divisor = playersRequired <= 0 ? 1 : playersRequired;
    return totalPrice / divisor;
  }

  bool hasJoined(String uid) => joinedPlayerIds.contains(uid);
  bool isHost(String uid) => hostUid == uid;

  OpenMatch copyWith({
    List<String>? joinedPlayerIds,
    List<String>? joinedPlayerNames,
    int? confirmedGuestCount,
    String? status,
    DateTime? updatedAt,
  }) {
    return OpenMatch(
      id: id,
      hostUid: hostUid,
      hostName: hostName,
      hostInitials: hostInitials,
      hostPhotoUrl: hostPhotoUrl,
      hostAvatarId: hostAvatarId,
      courtId: courtId,
      courtName: courtName,
      courtAddress: courtAddress,
      courtImageUrl: courtImageUrl,
      courtImageUrls: courtImageUrls,
      sportType: sportType,
      date: date,
      startTime: startTime,
      endTime: endTime,
      pricePerHour: pricePerHour,
      totalPrice: totalPrice,
      playersRequired: playersRequired,
      joinedPlayerIds: joinedPlayerIds ?? this.joinedPlayerIds,
      joinedPlayerNames: joinedPlayerNames ?? this.joinedPlayerNames,
      confirmedGuestCount: confirmedGuestCount ?? this.confirmedGuestCount,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'hostUid': hostUid,
    'hostName': hostName,
    'hostInitials': hostInitials,
    'hostPhotoUrl': hostPhotoUrl,
    'hostAvatarId': hostAvatarId,
    'courtId': courtId,
    'courtName': courtName,
    'courtAddress': courtAddress,
    'courtImageUrl': courtImageUrl,
    'courtImageUrls': courtImageUrls,
    'sportType': sportType,
    'date': Timestamp.fromDate(date),
    'startTime': startTime,
    'endTime': endTime,
    'pricePerHour': pricePerHour,
    'totalPrice': totalPrice,
    'playersRequired': playersRequired,
    'joinedPlayerIds': joinedPlayerIds,
    'joinedPlayerNames': joinedPlayerNames,
    'confirmedGuestCount': confirmedGuestCount,
    'status': status,
    if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
    if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
  };

  factory OpenMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return OpenMatch.fromMap({...data, 'id': doc.id});
  }

  factory OpenMatch.fromMap(Map<String, dynamic> map) {
    final courtImageUrl = (map['courtImageUrl'] as String?) ?? '';
    // Backward compat for old docs that only have the single image.
    final parsedUrls = _parseStringList(map['courtImageUrls']);
    final urls = parsedUrls.isNotEmpty
        ? parsedUrls
        : (courtImageUrl.isEmpty ? const <String>[] : [courtImageUrl]);

    return OpenMatch(
      id: (map['id'] as String?) ?? '',
      hostUid: (map['hostUid'] as String?) ?? '',
      hostName: (map['hostName'] as String?) ?? '',
      hostInitials: (map['hostInitials'] as String?) ?? '?',
      hostPhotoUrl: map['hostPhotoUrl'] as String?,
      hostAvatarId: map['hostAvatarId'] as String?,
      courtId: (map['courtId'] as String?) ?? '',
      courtName: (map['courtName'] as String?) ?? '',
      courtAddress: (map['courtAddress'] as String?) ?? '',
      courtImageUrl: courtImageUrl,
      courtImageUrls: urls,
      sportType: (map['sportType'] as String?) ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startTime: (map['startTime'] as String?) ?? '',
      endTime: (map['endTime'] as String?) ?? '',
      pricePerHour: _parseDouble(map['pricePerHour']) ?? 0,
      totalPrice: _parseDouble(map['totalPrice']) ?? 0,
      playersRequired: _parseInt(map['playersRequired']) ?? 0,
      joinedPlayerIds: _parseStringList(map['joinedPlayerIds']),
      joinedPlayerNames: _parseStringList(map['joinedPlayerNames']),
      // Missing → 0 so legacy docs read as "only real uids count".
      confirmedGuestCount: _parseInt(map['confirmedGuestCount']) ?? 0,
      // Missing status defaults to open — a half-written doc must
      // not accidentally read as `full` and hide itself.
      status: (map['status'] as String?) ?? OpenMatch.statusOpen,
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

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  static List<String> _parseStringList(dynamic raw) {
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const [];
  }
}
