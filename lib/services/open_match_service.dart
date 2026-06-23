import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/booking_draft.dart';
import '../models/open_match.dart';
import 'chat_service.dart';
import 'notification_service.dart';
import 'schedule_conflict_service.dart';

/// Firestore layer for `open_matches/{id}`.
///
/// Queries stay single-field (`where('status', whereIn: …)`) and
/// sort client-side so we don't need composite indexes.
///
/// Join is transactional: two users tapping the last spot can't both
/// succeed, and host-self-join / duplicate / cancelled / full are
/// all rejected inside the same atomic read-write.
///
/// Capacity is `joinedPlayerIds.length + confirmedGuestCount`, not
/// the array length — players the host already confirmed offline
/// still count toward `full` / `spotsLeft`.
class OpenMatchService {
  final FirebaseFirestore _db;
  final NotificationService _notifications;
  final ChatService _chatService;
  final ScheduleConflictService _conflicts;

  OpenMatchService({
    FirebaseFirestore? db,
    NotificationService? notifications,
    ChatService? chatService,
    ScheduleConflictService? conflicts,
  }) : _db = db ?? FirebaseFirestore.instance,
       _notifications = notifications ?? NotificationService(),
       _chatService = chatService ?? ChatService(),
       _conflicts =
           conflicts ??
           ScheduleConflictService(db: db ?? FirebaseFirestore.instance);

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('open_matches');

  /// Every visible open match, sorted by date + start time. Cancelled
  /// matches are filtered out client-side; full matches stay in so a
  /// user who taps a notification for a now-full match still lands on
  /// a real (disabled) details page.
  Stream<List<OpenMatch>> streamOpenMatches() {
    return _matches
        .where(
          'status',
          whereIn: const [OpenMatch.statusOpen, OpenMatch.statusFull],
        )
        .snapshots()
        .map((snap) {
          final matches = snap.docs
              .map((doc) => OpenMatch.fromDoc(doc))
              .toList();
          matches.sort((a, b) {
            final byDate = a.date.compareTo(b.date);
            if (byDate != 0) return byDate;
            return a.startTime.compareTo(b.startTime);
          });
          return matches;
        });
  }

  /// Every match where [userId] is host or joined player, including
  /// cancelled ones (MyBookings surfaces those under Past).
  ///
  /// Filtered client-side because Firestore can't express
  /// `hostUid == uid OR joinedPlayerIds arrayContains uid` without a
  /// composite index. Per-user match volume is small enough for a
  /// full collection scan in this phase.
  Stream<List<OpenMatch>> streamMatchesForUser(String userId) {
    return _matches.snapshots().map((snap) {
      final mine = <OpenMatch>[];
      for (final doc in snap.docs) {
        final m = OpenMatch.fromDoc(doc);
        if (m.hostUid == userId || m.joinedPlayerIds.contains(userId)) {
          mine.add(m);
        }
      }
      mine.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        if (byDate != 0) return byDate;
        return a.startTime.compareTo(b.startTime);
      });
      return mine;
    });
  }

  Future<OpenMatch?> getOpenMatch(String matchId) async {
    final snap = await _matches.doc(matchId).get();
    if (!snap.exists) return null;
    return OpenMatch.fromDoc(snap);
  }

  /// Live stream of a single match. Emits `null` if the doc goes
  /// away. Used by sent-invite cards so their "X / Y joined" line
  /// stays honest as other players accept or leave.
  Stream<OpenMatch?> streamOpenMatch(String matchId) {
    return _matches.doc(matchId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return OpenMatch.fromDoc(snap);
    });
  }

  /// Create an open match with the host pre-joined and
  /// `confirmedGuestCount = playersConfirmed - 1` so offline-confirmed
  /// guests count toward capacity without inventing fake uids.
  ///
  /// Schedule conflicts (court-occupied OR host-already-scheduled)
  /// throw distinct StateError codes before the write so the UI can
  /// surface the right SnackBar.
  Future<OpenMatch> createOpenMatch({
    required AppUser host,
    required BookingDraft draft,
  }) async {
    final dayOnly = DateTime(draft.date.year, draft.date.month, draft.date.day);

    await _conflicts.assertNoConflictForNewReservation(
      userId: host.uid,
      courtId: draft.court.id,
      date: dayOnly,
      startTime: draft.startTime,
      endTime: draft.endTime,
    );

    final ref = _matches.doc();
    final now = DateTime.now();
    final required = (draft.playersRequired ?? 1).clamp(1, 1000);
    // The host always counts as 1. Clamp away from stale picker
    // states that could under- or over-fill the match before any
    // remote user joins.
    final playersConfirmed = (draft.playersConfirmed ?? 1).clamp(1, required);
    final confirmedGuestCount = playersConfirmed - 1;
    final joinedIds = <String>[host.uid];
    final joinedNames = <String>[host.displayName];
    final imageUrls = List<String>.from(draft.court.imageUrls);
    final firstImageUrl = imageUrls.isNotEmpty ? imageUrls.first : '';
    final effectiveJoined = joinedIds.length + confirmedGuestCount;
    final initialStatus = effectiveJoined >= required
        ? OpenMatch.statusFull
        : OpenMatch.statusOpen;

    await ref.set({
      'hostUid': host.uid,
      'hostName': host.displayName,
      'hostInitials': host.initials,
      'hostPhotoUrl': host.photoUrl,
      'hostAvatarId': host.avatarId,
      'courtId': draft.court.id,
      'courtName': draft.court.name,
      'courtAddress': draft.court.address,
      'courtImageUrl': firstImageUrl,
      'courtImageUrls': imageUrls,
      'sportType': draft.sportType,
      'date': Timestamp.fromDate(dayOnly),
      'startTime': draft.startTime,
      'endTime': draft.endTime,
      'pricePerHour': draft.court.pricePerHour,
      'totalPrice': draft.totalPrice,
      'playersRequired': required,
      'joinedPlayerIds': joinedIds,
      'joinedPlayerNames': joinedNames,
      'confirmedGuestCount': confirmedGuestCount,
      'status': initialStatus,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final created = OpenMatch(
      id: ref.id,
      hostUid: host.uid,
      hostName: host.displayName,
      hostInitials: host.initials,
      hostPhotoUrl: host.photoUrl,
      hostAvatarId: host.avatarId,
      courtId: draft.court.id,
      courtName: draft.court.name,
      courtAddress: draft.court.address,
      courtImageUrl: firstImageUrl,
      courtImageUrls: imageUrls,
      sportType: draft.sportType,
      date: dayOnly,
      startTime: draft.startTime,
      endTime: draft.endTime,
      pricePerHour: draft.court.pricePerHour,
      totalPrice: draft.totalPrice,
      playersRequired: required,
      joinedPlayerIds: joinedIds,
      joinedPlayerNames: joinedNames,
      confirmedGuestCount: confirmedGuestCount,
      status: initialStatus,
      createdAt: now,
      updatedAt: now,
    );

    // Best-effort group thread create. Failure here must not roll
    // back the match — the next join/leave/chat-open will recreate
    // the thread idempotently.
    _chatService.createOrUpdateGroupThreadForMatch(created).catchError((_) {});

    return created;
  }

  /// Atomic join. Returns the post-join match.
  ///
  /// Throws:
  ///   * `StateError('match-not-found')` — doc deleted server-side.
  ///   * `StateError('match-cancelled')` — host cancelled.
  ///   * `StateError('match-full')` — capacity reached before this
  ///     user's transaction got there.
  ///   * `StateError('host-cannot-join')` — host tried to join own
  ///     match.
  ///   * `StateError('already-joined')` — uid already in the list.
  Future<OpenMatch> joinOpenMatch({
    required OpenMatch match,
    required AppUser user,
  }) async {
    // Personal schedule guard runs outside the transaction because
    // it scans other collections the transaction doesn't read.
    // `excludeMatchId` keeps the user's own entries on this same
    // match from showing up as false positives.
    await _conflicts.assertNoUserConflict(
      userId: user.uid,
      date: match.date,
      startTime: match.startTime,
      endTime: match.endTime,
      excludeMatchId: match.id,
    );

    final ref = _matches.doc(match.id);
    final updated = await _db.runTransaction<OpenMatch>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('match-not-found');
      }
      final current = OpenMatch.fromDoc(snap);
      if (current.isCancelled) {
        throw StateError('match-cancelled');
      }
      if (current.isHost(user.uid)) {
        throw StateError('host-cannot-join');
      }
      if (current.hasJoined(user.uid)) {
        throw StateError('already-joined');
      }
      // Effective count, not array length — a host claiming "5
      // confirmed" on a 6-required match has exactly 1 real spot
      // left for a remote joiner.
      if (current.effectiveJoinedCount >= current.playersRequired) {
        throw StateError('match-full');
      }

      final newIds = [...current.joinedPlayerIds, user.uid];
      final newNames = [...current.joinedPlayerNames, user.displayName];
      final newEffective = newIds.length + current.confirmedGuestCount;
      final newStatus = newEffective >= current.playersRequired
          ? OpenMatch.statusFull
          : OpenMatch.statusOpen;

      tx.update(ref, {
        'joinedPlayerIds': newIds,
        'joinedPlayerNames': newNames,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return current.copyWith(
        joinedPlayerIds: newIds,
        joinedPlayerNames: newNames,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    });

    // Best-effort group chat add. Swallow failures so the join
    // isn't rolled back.
    _chatService
        .addUserToGroupThread(match: updated, user: user)
        .catchError((_) {});

    return updated;
  }

  /// Host-only cancel. Flips status to `cancelled` and notifies every
  /// other real joined player so their MyBookings rows reflect it.
  ///
  /// Transactional so we can re-assert the caller is the host inside
  /// the same atomic read-write. Notifications fire after commit and
  /// are best-effort — a single notification write failure shouldn't
  /// roll back a successful cancel.
  ///
  /// Throws `match-not-found`, `not-host`, or `already-cancelled`.
  Future<OpenMatch> cancelOpenMatch({
    required OpenMatch match,
    required AppUser host,
  }) async {
    final ref = _matches.doc(match.id);
    final result = await _db.runTransaction<OpenMatch>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('match-not-found');
      }
      final current = OpenMatch.fromDoc(snap);
      if (!current.isHost(host.uid)) {
        throw StateError('not-host');
      }
      if (current.isCancelled) {
        throw StateError('already-cancelled');
      }
      tx.update(ref, {
        'status': OpenMatch.statusCancelled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return current.copyWith(
        status: OpenMatch.statusCancelled,
        updatedAt: DateTime.now(),
      );
    });

    final body =
        '${result.hostName} cancelled the match at ${result.courtName}.';
    for (final uid in result.joinedPlayerIds) {
      if (uid == host.uid) continue;
      _notifications
          .createNotification(
            userId: uid,
            title: 'Host cancelled the match',
            body: body,
            type: AppNotification.typeOpenMatchCancelled,
            targetType: AppNotification.targetMatch,
            targetId: result.id,
          )
          .catchError((_) {});
    }
    return result;
  }

  /// Joined player leave. Removes the user at the same index from
  /// both parallel arrays (never `arrayRemove` independently —
  /// they'd desync) and flips status back to open if a spot frees up.
  /// `playersRequired` and `confirmedGuestCount` aren't touched.
  ///
  /// Transactional so a host racing a cancel can't double-succeed
  /// against the same doc.
  ///
  /// Throws `match-not-found`, `match-cancelled`, `host-cannot-leave`,
  /// or `not-joined`. The host uses cancel instead of leave.
  Future<OpenMatch> leaveOpenMatch({
    required OpenMatch match,
    required AppUser user,
  }) async {
    final ref = _matches.doc(match.id);
    final result = await _db.runTransaction<OpenMatch>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw StateError('match-not-found');
      }
      final current = OpenMatch.fromDoc(snap);
      if (current.isCancelled) {
        throw StateError('match-cancelled');
      }
      if (current.isHost(user.uid)) {
        throw StateError('host-cannot-leave');
      }
      final idx = current.joinedPlayerIds.indexOf(user.uid);
      if (idx < 0) {
        throw StateError('not-joined');
      }
      final newIds = [...current.joinedPlayerIds]..removeAt(idx);
      final newNames = [...current.joinedPlayerNames];
      if (idx < newNames.length) newNames.removeAt(idx);
      final newEffective = newIds.length + current.confirmedGuestCount;
      final newStatus = newEffective >= current.playersRequired
          ? OpenMatch.statusFull
          : OpenMatch.statusOpen;
      tx.update(ref, {
        'joinedPlayerIds': newIds,
        'joinedPlayerNames': newNames,
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return current.copyWith(
        joinedPlayerIds: newIds,
        joinedPlayerNames: newNames,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    });

    // Host notification is the load-bearing signal; remaining-joined
    // fanout is a courtesy.
    _notifications
        .createNotification(
          userId: result.hostUid,
          title: 'Player left your match',
          body: '${user.displayName} left your match at ${result.courtName}.',
          type: AppNotification.typeMatchLeft,
          targetType: AppNotification.targetMatch,
          targetId: result.id,
        )
        .catchError((_) {});
    for (final uid in result.joinedPlayerIds) {
      if (uid == result.hostUid) continue;
      _notifications
          .createNotification(
            userId: uid,
            title: 'A player left the match',
            body: '${user.displayName} left the match at ${result.courtName}.',
            type: AppNotification.typeMatchLeft,
            targetType: AppNotification.targetMatch,
            targetId: result.id,
          )
          .catchError((_) {});
    }

    // Drop the leaver from the group thread. Their old messages
    // stay in history; the thread just disappears from their Groups
    // tab. Best-effort.
    _chatService
        .removeUserFromGroupThread(match: result, userId: user.uid)
        .catchError((_) {});

    return result;
  }
}
