import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/app_notification.dart';
import '../screens/booking_confirmed_page.dart';
import '../screens/player_details/invites_page.dart';
import '../screens/player_details/match_details_page.dart';
import 'booking_service.dart';
import 'invite_service.dart';
import 'open_match_service.dart';

/// Client-side FCM wiring.
///
/// What this does:
///   * Asks for notification permission.
///   * Stores the device's FCM token under `users/{uid}.fcmTokens`
///     via array-union so multi-device works.
///   * Subscribes to token-refresh + foreground / background /
///     cold-launch message streams.
///   * Shows a foreground SnackBar banner so the user notices new
///     events without opening the bell.
///   * Routes notification taps to the matching detail page using
///     the same `targetType + targetId` convention as in-app
///     notifications.
///
/// What this does NOT do:
///   * Send pushes. The Cloud Function in `/functions/index.js`
///     listens on `notifications/{id}` creates and dispatches to
///     FCM. Deploy with `firebase deploy --only functions`.
///   * Production iOS push. Requires an APNs auth key uploaded in
///     Firebase and an APNs entitlement on the build. On the iOS
///     simulator the token is null — expected.
///
/// All errors are swallowed and debug-printed. FCM availability
/// must never block app startup or any user flow.
class PushNotificationService {
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;
  final BookingService _bookingService;
  final OpenMatchService _openMatchService;
  final InviteService _inviteService;

  PushNotificationService({
    FirebaseFirestore? db,
    FirebaseMessaging? messaging,
    BookingService? bookingService,
    OpenMatchService? openMatchService,
    InviteService? inviteService,
  }) : _db = db ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance,
       _bookingService = bookingService ?? BookingService(),
       _openMatchService = openMatchService ?? OpenMatchService(),
       _inviteService = inviteService ?? InviteService();

  bool _initialised = false;

  /// Called once per signed-in session. Subsequent calls only
  /// re-store the token (cheap) so a sign-out / sign-in as a
  /// different user re-binds the device.
  Future<void> initForUser(String uid) async {
    if (_initialised) {
      await _storeTokenIfAvailable(uid);
      return;
    }
    _initialised = true;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      await _storeTokenIfAvailable(uid);

      _messaging.onTokenRefresh.listen(
        (token) async {
          await _writeToken(uid, token);
        },
        onError: (e) {
          debugPrint('PushNotificationService: onTokenRefresh error: $e');
        },
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Cold launch — defer the route push until after the first
      // frame; the navigator key isn't ready before runApp finishes.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _routeFromMessage(initial);
        });
      }

      FirebaseMessaging.onMessageOpenedApp.listen(_routeFromMessage);
    } catch (e) {
      // Common failure: iOS simulator without APNs. We deliberately
      // let the app run; Firestore in-app notifications still work.
      debugPrint('PushNotificationService: init failed: $e');
    }
  }

  Future<void> _storeTokenIfAvailable(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        debugPrint(
          'PushNotificationService: no FCM token yet (simulator or '
          "APNs not configured) — skipping store.",
        );
        return;
      }
      await _writeToken(uid, token);
    } catch (e) {
      debugPrint('PushNotificationService: getToken failed: $e');
    }
  }

  /// Idempotent — `arrayUnion` collapses repeats server-side.
  Future<void> _writeToken(String uid, String token) async {
    try {
      await _db.collection('users').doc(uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'fcmTokensUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('PushNotificationService: token write failed: $e');
    }
  }

  /// Foreground SnackBar banner. The View action runs the same
  /// resolver as a tap from the system tray.
  void _handleForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    final title = n?.title?.trim() ?? '';
    final body = n?.body?.trim() ?? '';
    final preview = [
      title,
      if (body.isNotEmpty) body,
    ].where((s) => s.isNotEmpty).join(' · ');
    if (preview.isEmpty) return;
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(preview),
        action: _hasRoutableTarget(message.data)
            ? SnackBarAction(
                label: 'View',
                onPressed: () => _routeFromMessage(message),
              )
            : null,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _hasRoutableTarget(Map<String, dynamic> data) {
    final type = data['targetType'] as String?;
    final id = data['targetId'] as String?;
    return (type != null && type.isNotEmpty) && (id != null && id.isNotEmpty);
  }

  /// Resolve `data.targetType` + `data.targetId` and push the
  /// matching detail screen. Mirrors NotificationsPage's tap
  /// routing so a tray tap and an in-app tap reach the same place.
  Future<void> _routeFromMessage(RemoteMessage message) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    final data = message.data;
    final type = data['targetType'] as String?;
    final id = data['targetId'] as String?;
    if (type == null || id == null || id.isEmpty) return;

    try {
      switch (type) {
        case AppNotification.targetBooking:
          final booking = await _bookingService.getBooking(id);
          if (booking == null) {
            _toast('This booking is no longer available.');
            return;
          }
          navigator.push(
            MaterialPageRoute(
              builder: (_) => BookingConfirmedPage(booking: booking),
            ),
          );
          break;
        case AppNotification.targetMatch:
          final match = await _openMatchService.getOpenMatch(id);
          if (match == null) {
            _toast('This match is no longer available.');
            return;
          }
          navigator.push(
            MaterialPageRoute(builder: (_) => MatchDetailsPage(match: match)),
          );
          break;
        case AppNotification.targetInvite:
          // Pending invite → Received tab; resolved invite →
          // MatchDetails when the match still exists.
          final invite = await _inviteService.getInvite(id);
          if (invite == null || invite.isPending) {
            navigator.push(
              MaterialPageRoute(
                builder: (_) =>
                    const InvitesPage(initialTab: InviteTab.received),
              ),
            );
            return;
          }
          final match = await _openMatchService.getOpenMatch(invite.matchId);
          if (match == null) {
            _toast('This match is no longer available.');
            return;
          }
          navigator.push(
            MaterialPageRoute(builder: (_) => MatchDetailsPage(match: match)),
          );
          break;
        default:
          return;
      }
    } catch (e) {
      debugPrint('PushNotificationService: route failed: $e');
      _toast("Couldn't open that notification.");
    }
  }

  void _toast(String text) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}
