import 'package:cloud_firestore/cloud_firestore.dart';

import 'id_verification.dart';
import 'user_location.dart';

/// A single per-day availability window. 24-hour `HH:mm` strings so
/// they round-trip cleanly through Firestore and across timezones.
class AvailabilitySlot {
  final String start;
  final String end;

  const AvailabilitySlot({required this.start, required this.end});

  /// Default when the user toggles a day on without picking a time.
  static const AvailabilitySlot defaultSlot = AvailabilitySlot(
    start: '18:00',
    end: '21:00',
  );

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  factory AvailabilitySlot.fromMap(Map<String, dynamic> map) {
    return AvailabilitySlot(
      start: (map['start'] as String?) ?? defaultSlot.start,
      end: (map['end'] as String?) ?? defaultSlot.end,
    );
  }
}

class AppUser {
  /// Shared validation constants for every profile editor.
  static const int minNameLength = 2;
  static const int maxNameLength = 30;
  static const int minAge = 13;
  static const int maxAge = 120;
  static const int maxPostalCodeLength = 12;
  static const int maxBioLength = 280;

  final String uid;
  final String? email;
  final String? phone;
  final String firstName;
  final String lastName;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
  final int? age;
  final String? postalCode;
  final String? bio;
  final UserLocation? location;
  final IdVerification? idVerification;
  final List<String> sports;
  final Map<String, AvailabilitySlot> availability;
  final bool profileVisible;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.uid,
    this.email,
    this.phone,
    required this.firstName,
    required this.lastName,
    String? displayName,
    this.photoUrl,
    this.avatarId,
    this.age,
    this.postalCode,
    this.bio,
    this.location,
    this.idVerification,
    this.sports = const [],
    this.availability = const {},
    this.profileVisible = true,
    required this.createdAt,
    required this.updatedAt,
  }) : displayName = displayName ?? buildDisplayName(firstName, lastName);

  /// Public so name-changing call sites write a consistent string.
  static String buildDisplayName(String first, String last) {
    final f = first.trim();
    final l = last.trim();
    if (l.isEmpty) return f;
    return '$f $l';
  }

  String get initials {
    final f = firstName.trim();
    final l = lastName.trim();
    if (f.isEmpty && l.isEmpty) return 'U';
    if (l.isEmpty) return f[0].toUpperCase();
    return '${f[0]}${l[0]}'.toUpperCase();
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? photoUrl,
    String? avatarId,
    String? bio,
    UserLocation? location,
    IdVerification? idVerification,
    List<String>? sports,
    Map<String, AvailabilitySlot>? availability,
    bool? profileVisible,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      phone: phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarId: avatarId ?? this.avatarId,
      age: age,
      postalCode: postalCode,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      idVerification: idVerification ?? this.idVerification,
      sports: sports ?? this.sports,
      availability: availability ?? this.availability,
      profileVisible: profileVisible ?? this.profileVisible,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'phone': phone,
    'firstName': firstName,
    'lastName': lastName,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'avatarId': avatarId,
    'age': age,
    'postalCode': postalCode,
    'bio': bio,
    'location': location?.toMap(),
    'idVerification': idVerification?.toMap(),
    'sports': sports,
    'availability': availability.map(
      (day, slot) => MapEntry(day, slot.toMap()),
    ),
    'profileVisible': profileVisible,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      firstName: (map['firstName'] as String?) ?? '',
      lastName: (map['lastName'] as String?) ?? '',
      displayName: map['displayName'] as String?,
      photoUrl: map['photoUrl'] as String?,
      avatarId: map['avatarId'] as String?,
      age: _parseInt(map['age']),
      postalCode: map['postalCode'] as String?,
      bio: map['bio'] as String?,
      location: _safeWhenMap(map['location'], UserLocation.fromMap, 'location'),
      idVerification: _safeWhenMap(
        map['idVerification'],
        IdVerification.fromMap,
        'idVerification',
      ),
      sports: (map['sports'] as List<dynamic>?)?.cast<String>() ?? const [],
      availability: _parseAvailability(map['availability']),
      profileVisible: (map['profileVisible'] as bool?) ?? true,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Returns null when the value isn't a map OR when [parse] throws.
  /// The try/catch is load-bearing — a malformed nested field would
  /// otherwise propagate to `getUser`, flip status to needsOnboarding,
  /// and the next `set()` would wipe the rest of the user's doc.
  static T? _safeWhenMap<T>(
    dynamic raw,
    T Function(Map<String, dynamic>) parse,
    String field,
  ) {
    if (raw is! Map) return null;
    try {
      return parse(raw.map((k, v) => MapEntry(k as String, v)));
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('AppUser.fromMap: failed to parse "$field": $e');
        return true;
      }());
      return null;
    }
  }

  static int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  /// Tolerates the older flat `List<String>` schema by promoting each
  /// day to a default window.
  static Map<String, AvailabilitySlot> _parseAvailability(dynamic raw) {
    if (raw == null) return const {};
    if (raw is List) {
      final result = <String, AvailabilitySlot>{};
      for (final day in raw) {
        if (day is String && day.isNotEmpty) {
          result[day] = AvailabilitySlot.defaultSlot;
        }
      }
      return result;
    }
    if (raw is Map) {
      final result = <String, AvailabilitySlot>{};
      raw.forEach((day, value) {
        if (day is String && value is Map) {
          result[day] = AvailabilitySlot.fromMap(
            value.map((k, v) => MapEntry(k as String, v)),
          );
        }
      });
      return result;
    }
    return const {};
  }
}
