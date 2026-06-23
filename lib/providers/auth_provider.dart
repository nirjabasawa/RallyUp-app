import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/id_verification.dart';
import '../models/signup_form_data.dart';
import '../models/user_location.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/user_service.dart';

enum AuthStatus { loading, unauthenticated, needsOnboarding, authenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;
  final PushNotificationService _pushNotificationService;

  StreamSubscription<User?>? _authSub;
  AuthStatus _status = AuthStatus.loading;
  AppUser? _currentUser;
  String? _lastError;

  AuthProvider({
    required AuthService authService,
    required UserService userService,
    PushNotificationService? pushNotificationService,
  }) : _authService = authService,
       _userService = userService,
       _pushNotificationService =
           pushNotificationService ?? PushNotificationService() {
    _authSub = _authService.authStateChanges.listen(_onAuthChange);
  }

  AuthStatus get status => _status;
  AppUser? get currentUser => _currentUser;
  String? get lastError => _lastError;

  Future<void> _onAuthChange(User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Mid-session safety: if we already have a valid user for this
    // uid, treat fetch failures / transient missing-doc reads as
    // "keep what we have". Otherwise a network blip during a token
    // refresh would null _currentUser and the whole UI would fall
    // back to the "Welcome / U" empty state.
    final hadGoodUser =
        _currentUser != null &&
        _currentUser!.uid == firebaseUser.uid &&
        _status == AuthStatus.authenticated;

    try {
      final user = await _userService.getUser(firebaseUser.uid);
      if (user != null) {
        _currentUser = user;
        _status = AuthStatus.authenticated;
      } else if (!hadGoodUser) {
        _currentUser = null;
        _status = AuthStatus.needsOnboarding;
      }
    } catch (e) {
      _lastError = e.toString();
      if (!hadGoodUser) {
        _currentUser = null;
        _status = AuthStatus.needsOnboarding;
      }
    }
    notifyListeners();

    // Best-effort FCM init. PushNotificationService swallows its own
    // errors so a denied permission or missing APNs key can't crash
    // this listener.
    if (_status == AuthStatus.authenticated && _currentUser != null) {
      // ignore: unawaited_futures
      _pushNotificationService.initForUser(_currentUser!.uid);
    }
  }

  Future<void> completeOnboarding(SignupFormData formData) async {
    final fbUser = _authService.currentFirebaseUser;
    if (fbUser == null) {
      throw StateError('Cannot complete onboarding without an auth user.');
    }
    final now = DateTime.now();
    final firstName = formData.firstName.trim();
    final lastName = formData.lastName.trim();
    final sports = formData.selectedSports.toList();

    // If a doc already exists this is a re-entry into onboarding —
    // partial-update only the fields onboarding collects. A full
    // `createUser` would overwrite idVerification, location,
    // profileVisible, etc.
    final existing = await _userService.getUser(fbUser.uid);
    if (existing != null) {
      final displayName = AppUser.buildDisplayName(firstName, lastName);
      await _userService.updateFields(fbUser.uid, {
        'firstName': firstName,
        'lastName': lastName,
        'displayName': displayName,
        'avatarId': formData.avatarId,
        'sports': sports,
        if (formData.location != null) ...{
          'location': formData.location!.toMap(),
          ..._locationShadow(formData.location),
        },
      });
      _currentUser = existing.copyWith(
        firstName: firstName,
        lastName: lastName,
        avatarId: formData.avatarId,
        location: formData.location ?? existing.location,
        sports: sports,
        updatedAt: now,
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    final user = AppUser(
      uid: fbUser.uid,
      email: fbUser.email,
      phone: fbUser.phoneNumber,
      firstName: firstName,
      lastName: lastName,
      avatarId: formData.avatarId,
      location: formData.location,
      sports: sports,
      createdAt: now,
      updatedAt: now,
    );

    // Top-level location shadow fields are stored alongside the
    // nested `location` so future geo queries can use them without
    // a backfill.
    await _userService.createUser(
      user,
      extras: _locationShadow(formData.location),
    );
    _currentUser = user;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  /// Top-level Firestore copies of the nested `location` fields, so
  /// future geo queries don't need to index inside a nested map.
  Map<String, dynamic> _locationShadow(UserLocation? loc) {
    if (loc == null) return const {};
    return {
      'locationCity': loc.city,
      'locationRegion': loc.region,
      'locationCountry': loc.country,
      'locationLat': loc.lat,
      'locationLng': loc.lng,
    };
  }

  /// Pass `null` for `age` or `postalCode` to clear.
  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required int? age,
    required String? postalCode,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    final newFirstName = firstName.trim();
    final newLastName = lastName.trim();
    final newPostalCode = postalCode?.trim();
    final newDisplayName = AppUser.buildDisplayName(newFirstName, newLastName);
    final now = DateTime.now();

    await _userService.updateFields(user.uid, {
      'firstName': newFirstName,
      'lastName': newLastName,
      'displayName': newDisplayName,
      'age': age,
      'postalCode': newPostalCode,
    });

    // Preserve every field updateProfile doesn't touch (location,
    // idVerification, profileVisible, bio) so they don't get
    // silently cleared from the local copy.
    _currentUser = AppUser(
      uid: user.uid,
      email: user.email,
      phone: user.phone,
      firstName: newFirstName,
      lastName: newLastName,
      displayName: newDisplayName,
      photoUrl: user.photoUrl,
      avatarId: user.avatarId,
      age: age,
      postalCode: newPostalCode,
      bio: user.bio,
      location: user.location,
      idVerification: user.idVerification,
      sports: user.sports,
      availability: user.availability,
      profileVisible: user.profileVisible,
      createdAt: user.createdAt,
      updatedAt: now,
    );
    notifyListeners();
  }

  /// Trimmed; empty/whitespace clears. The call site enforces
  /// [AppUser.maxBioLength] via a TextInputFormatter.
  Future<void> updateBio(String? bio) async {
    final user = _currentUser;
    if (user == null) return;
    final normalised = (bio == null || bio.trim().isEmpty) ? null : bio.trim();
    await _userService.updateFields(user.uid, {'bio': normalised});
    _currentUser = user.copyWith(bio: normalised, updatedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> updateSports(List<String> sports) async {
    final user = _currentUser;
    if (user == null) return;
    await _userService.updateFields(user.uid, {'sports': sports});
    _currentUser = user.copyWith(sports: sports, updatedAt: DateTime.now());
    notifyListeners();
  }

  Future<void> updateAvailability(
    Map<String, AvailabilitySlot> availability,
  ) async {
    final user = _currentUser;
    if (user == null) return;
    final firestorePayload = availability.map(
      (day, slot) => MapEntry(day, slot.toMap()),
    );
    await _userService.updateFields(user.uid, {
      'availability': firestorePayload,
    });
    _currentUser = user.copyWith(
      availability: availability,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> updateAvatar(String? avatarId) async {
    final user = _currentUser;
    if (user == null) return;
    await _userService.updateFields(user.uid, {'avatarId': avatarId});
    _currentUser = user.copyWith(avatarId: avatarId, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Clears `avatarId` so the photo wins in the UserAvatar priority
  /// chain (photoUrl > avatarId > initials).
  Future<void> setProfilePhotoUrl(String url) async {
    final user = _currentUser;
    if (user == null) return;
    final now = DateTime.now();
    await _userService.updateFields(user.uid, {
      'photoUrl': url,
      'avatarId': null,
    });
    _currentUser = AppUser(
      uid: user.uid,
      email: user.email,
      phone: user.phone,
      firstName: user.firstName,
      lastName: user.lastName,
      photoUrl: url,
      avatarId: null,
      age: user.age,
      postalCode: user.postalCode,
      bio: user.bio,
      location: user.location,
      idVerification: user.idVerification,
      sports: user.sports,
      availability: user.availability,
      profileVisible: user.profileVisible,
      createdAt: user.createdAt,
      updatedAt: now,
    );
    notifyListeners();
  }

  /// Fall back to initials by clearing both photo and avatar.
  Future<void> clearProfileImage() async {
    final user = _currentUser;
    if (user == null) return;
    final now = DateTime.now();
    await _userService.updateFields(user.uid, {
      'photoUrl': null,
      'avatarId': null,
    });
    _currentUser = AppUser(
      uid: user.uid,
      email: user.email,
      phone: user.phone,
      firstName: user.firstName,
      lastName: user.lastName,
      photoUrl: null,
      avatarId: null,
      age: user.age,
      postalCode: user.postalCode,
      bio: user.bio,
      location: user.location,
      idVerification: user.idVerification,
      sports: user.sports,
      availability: user.availability,
      profileVisible: user.profileVisible,
      createdAt: user.createdAt,
      updatedAt: now,
    );
    notifyListeners();
  }

  Future<void> updateProfileVisibility(bool visible) async {
    final user = _currentUser;
    if (user == null) return;
    await _userService.updateFields(user.uid, {'profileVisible': visible});
    _currentUser = user.copyWith(
      profileVisible: visible,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> updateLocation(UserLocation location) async {
    final user = _currentUser;
    if (user == null) return;
    await _userService.updateFields(user.uid, {'location': location.toMap()});
    _currentUser = user.copyWith(location: location, updatedAt: DateTime.now());
    notifyListeners();
  }

  /// Submit-for-review only. Approve / reject transitions belong to
  /// [AdminService.setVerificationStatus].
  Future<void> submitIdVerification(IdVerification record) async {
    final user = _currentUser;
    if (user == null) return;
    if (record.status != IdVerificationStatus.submitted) {
      throw ArgumentError(
        'submitIdVerification only accepts status=submitted.',
      );
    }
    await _userService.updateFields(user.uid, {
      'idVerification': record.toMap(),
    });
    _currentUser = user.copyWith(
      idVerification: record,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  /// Auth-first delete. Local state is torn down only AFTER
  /// `fbUser.delete()` succeeds, so a throw (e.g.
  /// `requires-recent-login`) leaves the user signed in and the
  /// caller can show a retry SnackBar. The Firestore doc delete is
  /// best-effort after that — an orphaned doc is reaped by an admin
  /// job and can't affect the UI.
  Future<void> deleteAccount() async {
    final fbUser = _authService.currentFirebaseUser;
    if (fbUser == null) return;
    final uid = fbUser.uid;

    await fbUser.delete();

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _lastError = null;
    notifyListeners();

    try {
      await _userService.deleteUser(uid);
    } catch (e) {
      debugPrint(
        'deleteAccount: auth user $uid deleted, Firestore cleanup '
        'failed: $e (orphan doc)',
      );
    }
  }

  /// Clears local state synchronously so listeners flip to the
  /// unauthenticated branch by the time the await returns — no
  /// reliance on the auth-state listener's async hop.
  Future<void> signOut() async {
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _lastError = null;
    notifyListeners();
    await _authService.signOut();
  }

  /// Returns null on success or a friendly error string. We surface
  /// `user-not-found` explicitly rather than silently treating it as
  /// success — production would hide it to prevent email
  /// enumeration, but the demo benefits from a clear "sign up first"
  /// signal.
  Future<String?> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return 'Enter the email you signed up with.';
    try {
      await _authService.sendPasswordResetEmail(trimmed);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return "That doesn't look like a valid email address.";
        case 'user-not-found':
          return "No account is registered for that email. "
              'Sign up first, then try Reset Password from Account '
              'Settings.';
        case 'too-many-requests':
          return 'Too many attempts. Try again in a few minutes.';
        default:
          return "Couldn't send the reset email. Try again.";
      }
    } catch (_) {
      return "Couldn't send the reset email. Try again.";
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
