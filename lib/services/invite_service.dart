import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/invite.dart';
import '../models/open_match.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'open_match_service.dart';

/// Reads + writes `invites/{id}` docs.
///
/// Each invite ties one host's open match to one specific invitee.
/// Capacity, host identity, and duplicate-invite guards are enforced
/// against the live match doc inside a Firestore transaction.
///
/// Notifications fire best-effort after the primary mutation
/// commits; a notification write failure never rolls back the
/// underlying create/accept/decline.
class InviteService {
  final FirebaseFirestore _db;
  final NotificationService _notifications;
  final OpenMatchService _openMatchService;
  final ChatService _chatService;

  InviteService({
    FirebaseFirestore? db,
    NotificationService? notifications,
    OpenMatchService? openMatchService,
    ChatService? chatService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _notifications = notifications ?? NotificationService(),
       _openMatchService = openMatchService ?? OpenMatchService(),
       _chatService = chatService ?? ChatService();

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  // ─── Reads ──────────────────────────────────────────────────────

  /// Sent by [userId], newest first. Sorted client-side to avoid a
  /// composite index on `fromUserId + createdAt`.
  Stream<List<Invite>> streamSentInvites(String userId) {
    return _invites.where('fromUserId', isEqualTo: userId).snapshots().map((
      snap,
    ) {
      final list = snap.docs.map((doc) => Invite.fromDoc(doc)).toList();
      list.sort((a, b) {
        final aT = a.createdAt ?? DateTime.now();
        final bT = b.createdAt ?? DateTime.now();
        return bT.compareTo(aT);
      });
      return list;
    });
  }

  Stream<List<Invite>> streamReceivedInvites(String userId) {
    return _invites.where('toUserId', isEqualTo: userId).snapshots().map((
      snap,
    ) {
      final list = snap.docs.map((doc) => Invite.fromDoc(doc)).toList();
      list.sort((a, b) {
        final aT = a.createdAt ?? DateTime.now();
        final bT = b.createdAt ?? DateTime.now();
        return bT.compareTo(aT);
      });
      return list;
    });
  }

  /// Pending invites for [matchId] — InviteToMatchPage uses this so
  /// the host doesn't see a player who already has a pending invite.
  Stream<List<Invite>> streamPendingInvitesForMatch(String matchId) {
    return _invites
        .where('matchId', isEqualTo: matchId)
        .where('status', isEqualTo: Invite.statusPending)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Invite.fromDoc(doc)).toList());
  }

  Future<Invite?> getInvite(String inviteId) async {
    final snap = await _invites.doc(inviteId).get();
    if (!snap.exists) return null;
    return Invite.fromDoc(snap);
  }

  // ─── Create ─────────────────────────────────────────────────────

  /// Create a pending invite from [fromUser] to [toUser] for [match].
  /// All guards are checked against the live match doc inside the
  /// transaction.
  ///
  /// Throws `match-not-found`, `not-host`, `match-cancelled`,
  /// `match-full`, `invitee-is-host`, `invitee-already-joined`, or
  /// `duplicate-invite`.
  Future<Invite> createInvite({
    required AppUser fromUser,
    required AppUser toUser,
    required OpenMatch match,
  }) async {
    // Duplicate check is pre-transaction because `where(...)` queries
    // can't run inside one. A same-millisecond race could create two
    // pending invites — the UI keeps both visible until one resolves.
    final dupSnap = await _invites
        .where('matchId', isEqualTo: match.id)
        .where('toUserId', isEqualTo: toUser.uid)
        .get();
    final hasDuplicate = dupSnap.docs.any((d) {
      final inv = Invite.fromDoc(d);
      return inv.isPending || inv.isAccepted;
    });
    if (hasDuplicate) {
      throw StateError('duplicate-invite');
    }

    final newDoc = _invites.doc();
    final invite = await _db.runTransaction<Invite>((tx) async {
      final ref = _db.collection('open_matches').doc(match.id);
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('match-not-found');
      }
      final current = OpenMatch.fromDoc(snap);
      if (!current.isHost(fromUser.uid)) {
        throw StateError('not-host');
      }
      if (current.isCancelled) {
        throw StateError('match-cancelled');
      }
      if (current.isFull ||
          current.effectiveJoinedCount >= current.playersRequired) {
        throw StateError('match-full');
      }
      if (current.isHost(toUser.uid)) {
        throw StateError('invitee-is-host');
      }
      if (current.hasJoined(toUser.uid)) {
        throw StateError('invitee-already-joined');
      }

      final payload = {
        'matchId': current.id,
        'fromUserId': fromUser.uid,
        'fromUserName': fromUser.displayName,
        'fromUserInitials': fromUser.initials,
        'fromUserPhotoUrl': fromUser.photoUrl,
        'fromUserAvatarId': fromUser.avatarId,
        'toUserId': toUser.uid,
        'toUserName': toUser.displayName,
        'toUserInitials': toUser.initials,
        'toUserPhotoUrl': toUser.photoUrl,
        'toUserAvatarId': toUser.avatarId,
        'courtId': current.courtId,
        'courtName': current.courtName,
        'courtAddress': current.courtAddress,
        'courtImageUrl': current.courtImageUrl,
        'sportType': current.sportType,
        'date': Timestamp.fromDate(current.date),
        'startTime': current.startTime,
        'endTime': current.endTime,
        'playersRequired': current.playersRequired,
        'effectiveJoinedCountAtSend': current.effectiveJoinedCount,
        'status': Invite.statusPending,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      tx.set(newDoc, payload);

      return Invite(
        id: newDoc.id,
        matchId: current.id,
        fromUserId: fromUser.uid,
        fromUserName: fromUser.displayName,
        fromUserInitials: fromUser.initials,
        fromUserPhotoUrl: fromUser.photoUrl,
        fromUserAvatarId: fromUser.avatarId,
        toUserId: toUser.uid,
        toUserName: toUser.displayName,
        toUserInitials: toUser.initials,
        toUserPhotoUrl: toUser.photoUrl,
        toUserAvatarId: toUser.avatarId,
        courtId: current.courtId,
        courtName: current.courtName,
        courtAddress: current.courtAddress,
        courtImageUrl: current.courtImageUrl,
        sportType: current.sportType,
        date: current.date,
        startTime: current.startTime,
        endTime: current.endTime,
        playersRequired: current.playersRequired,
        effectiveJoinedCountAtSend: current.effectiveJoinedCount,
        status: Invite.statusPending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    });

    _notifications
        .createNotification(
          userId: toUser.uid,
          title: 'You were invited to a match',
          body:
              '${fromUser.displayName} invited you to '
              '${invite.sportType} at ${invite.courtName}.',
          type: AppNotification.typeInviteReceived,
          targetType: AppNotification.targetInvite,
          targetId: invite.id,
        )
        .catchError((_) {});

    return invite;
  }

  // ─── Accept ─────────────────────────────────────────────────────

  /// Accept an invite. Delegates to [OpenMatchService.joinOpenMatch]
  /// for the actual capacity / duplicate / host checks, then flips
  /// the invite to `accepted`, ensures the user is on the group
  /// thread, and notifies the host.
  ///
  /// Returns the post-join match so the caller can push
  /// MatchJoinedPage with the right state.
  ///
  /// Throws `invite-not-found`, `not-invitee`, `invite-not-pending`,
  /// plus anything `joinOpenMatch` can throw.
  Future<OpenMatch> acceptInvite({
    required Invite invite,
    required AppUser user,
  }) async {
    if (invite.toUserId != user.uid) {
      throw StateError('not-invitee');
    }
    // Re-read so a stale local "pending" can't double-accept.
    final fresh = await getInvite(invite.id);
    if (fresh == null) {
      throw StateError('invite-not-found');
    }
    if (!fresh.isPending) {
      throw StateError('invite-not-pending');
    }

    final match = await _openMatchService.getOpenMatch(fresh.matchId);
    if (match == null) {
      throw StateError('match-not-found');
    }

    final updated = await _openMatchService.joinOpenMatch(
      match: match,
      user: user,
    );

    await _invites.doc(fresh.id).set({
      'status': Invite.statusAccepted,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // joinOpenMatch already adds the user to the group thread, but
    // arrayUnion is idempotent and this guards against a future
    // change to the join flow that might skip it.
    _chatService
        .addUserToGroupThread(match: updated, user: user)
        .catchError((_) {});

    _notifications
        .createNotification(
          userId: fresh.fromUserId,
          title: 'Invite accepted',
          body:
              '${user.displayName} accepted your invite for '
              '${fresh.sportType} at ${fresh.courtName}.',
          type: AppNotification.typeInviteAccepted,
          targetType: AppNotification.targetMatch,
          targetId: fresh.matchId,
        )
        .catchError((_) {});

    return updated;
  }

  // ─── Decline ────────────────────────────────────────────────────

  /// Flip the invite to `declined` and notify the host. The match
  /// doc is untouched — the invitee was never on the player list.
  ///
  /// Throws `invite-not-found`, `not-invitee`, or `invite-not-pending`.
  Future<Invite> declineInvite({
    required Invite invite,
    required AppUser user,
  }) async {
    if (invite.toUserId != user.uid) {
      throw StateError('not-invitee');
    }
    final fresh = await getInvite(invite.id);
    if (fresh == null) {
      throw StateError('invite-not-found');
    }
    if (!fresh.isPending) {
      throw StateError('invite-not-pending');
    }

    await _invites.doc(fresh.id).set({
      'status': Invite.statusDeclined,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _notifications
        .createNotification(
          userId: fresh.fromUserId,
          title: 'Invite declined',
          body:
              '${user.displayName} declined your invite for '
              '${fresh.sportType} at ${fresh.courtName}.',
          type: AppNotification.typeInviteDeclined,
          targetType: AppNotification.targetInvite,
          targetId: fresh.id,
        )
        .catchError((_) {});

    return fresh.copyWith(
      status: Invite.statusDeclined,
      updatedAt: DateTime.now(),
    );
  }

  // ─── Bulk cancel (host cancelled the match) ─────────────────────

  /// Flip every pending invite for [matchId] to `cancelled` in a
  /// single batched write. Called from MyBookings after a host's
  /// cancel succeeds.
  ///
  /// Each affected invitee then receives a best-effort
  /// `typeOpenMatchCancelled` notification. This is the companion
  /// fanout to `OpenMatchService.cancelOpenMatch` — that one targets
  /// host + accepted players (everyone in `joinedPlayerIds`); this
  /// one targets pending invitees, who never made it into that list.
  Future<void> cancelInvitesForMatch(String matchId) async {
    final pending = await _invites
        .where('matchId', isEqualTo: matchId)
        .where('status', isEqualTo: Invite.statusPending)
        .get();
    if (pending.docs.isEmpty) return;
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    final cancelled = <Invite>[];
    for (final doc in pending.docs) {
      batch.update(doc.reference, {
        'status': Invite.statusCancelled,
        'updatedAt': now,
      });
      cancelled.add(Invite.fromDoc(doc));
    }
    await batch.commit();

    for (final inv in cancelled) {
      _notifications
          .createNotification(
            userId: inv.toUserId,
            title: 'Match cancelled',
            body:
                '${inv.fromUserName} cancelled the '
                '${inv.sportType} match at ${inv.courtName} '
                "you were invited to. The invite is no longer active.",
            type: AppNotification.typeOpenMatchCancelled,
            targetType: AppNotification.targetMatch,
            targetId: inv.matchId,
          )
          .catchError((_) {});
    }
  }
}
