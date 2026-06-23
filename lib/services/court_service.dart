import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/cloudinary_config.dart';
import '../models/court.dart';

/// Reads + seeds `courts` documents. Filtering by `isActive` and
/// sorting (city → name) are done client-side; the catalogue is
/// small (tens of venues) and we don't ship composite indexes.
class CourtService {
  final FirebaseFirestore _db;

  CourtService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _courts =>
      _db.collection('courts');

  Stream<List<Court>> streamActiveCourts() {
    return _courts.snapshots().map((snap) {
      final courts = snap.docs
          .map((doc) => Court.fromDoc(doc))
          .where((c) => c.isActive)
          .toList();
      courts.sort((a, b) {
        final byCity = a.city.toLowerCase().compareTo(b.city.toLowerCase());
        if (byCity != 0) return byCity;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return courts;
    });
  }

  Future<Court?> getCourt(String courtId) async {
    final snap = await _courts.doc(courtId).get();
    if (!snap.exists) return null;
    return Court.fromDoc(snap);
  }

  /// Cloudinary delivery URL for a public ID under `rallyup/courts/`.
  /// `f_auto,q_auto` lets Cloudinary pick the best format + quality
  /// for the requesting client.
  static String cloudinaryCourtImage(String publicId) {
    return 'https://res.cloudinary.com/${CloudinaryConfig.cloudName}'
        '/image/upload/f_auto,q_auto/$publicId';
  }

  /// Debug-only first-run seed. Idempotent: bails on the first
  /// `limit(1)` hit, uses deterministic doc ids so a partial prior
  /// seed merges instead of duplicating. Errors are swallowed —
  /// seeding must never crash startup.
  Future<void> seedCourtsIfEmpty() async {
    try {
      final existing = await _courts.limit(1).get();
      if (existing.docs.isNotEmpty) return;

      final batch = _db.batch();
      final now = FieldValue.serverTimestamp();
      for (final entry in _seedData) {
        final ref = _courts.doc(entry.id);
        batch.set(ref, {
          ...entry.toMapWithoutTimestamps(cloudinaryCourtImage),
          'createdAt': now,
          'updatedAt': now,
        });
      }
      await batch.commit();
      debugPrint('CourtService: seeded ${_seedData.length} courts.');
      // Sample URL for manual sanity check against Cloudinary.
      if (_seedData.isNotEmpty && _seedData.first.imagePublicIds.isNotEmpty) {
        debugPrint(
          'CourtService: sample image URL = '
          '${cloudinaryCourtImage(_seedData.first.imagePublicIds.first)}',
        );
      }
    } catch (e) {
      debugPrint('CourtService: seedCourtsIfEmpty failed: $e');
    }
  }

  /// Debug-only self-heal for courts whose `imageUrls` array is
  /// missing or empty (an older seed format). Walks the known
  /// `_seedData` ids and fills in the URLs from `imagePublicIds`.
  /// Never touches hand-authored docs.
  Future<void> repairCourtImagesIfNeeded() async {
    try {
      int repaired = 0;
      for (final entry in _seedData) {
        final ref = _courts.doc(entry.id);
        final snap = await ref.get();
        if (!snap.exists) continue;
        final data = snap.data() ?? const <String, dynamic>{};
        final rawUrls = data['imageUrls'];
        final currentUrls = (rawUrls is List)
            ? rawUrls.whereType<String>().toList()
            : const <String>[];
        if (currentUrls.isNotEmpty) continue;

        final urls = entry.imagePublicIds.map(cloudinaryCourtImage).toList();
        await ref.update({
          'imageUrls': urls,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        repaired++;
        debugPrint(
          'CourtService: repaired imageUrls on ${entry.id} '
          '(${urls.length} urls). First URL: ${urls.first}',
        );
      }
      if (repaired == 0) {
        debugPrint('CourtService: no courts needed image repair.');
      }
    } catch (e) {
      debugPrint('CourtService: repairCourtImagesIfNeeded failed: $e');
    }
  }

  static const List<_SeedCourt> _seedData = [
    _SeedCourt(
      id: 'santa_clara_tennis_center',
      name: 'Santa Clara Tennis Center',
      sportTypes: ['Tennis'],
      city: 'Santa Clara',
      region: 'CA',
      address: 'Santa Clara, CA',
      lat: 37.3541,
      lng: -121.9552,
      rating: 4.6,
      pricePerHour: 12,
      amenities: ['Lighting', 'Parking', 'Restrooms'],
      description: 'Public tennis courts in Santa Clara.',
      imagePublicIds: [
        'rallyup/courts/santa_clara_tennis_center/tennis2_njjjro',
        'rallyup/courts/santa_clara_tennis_center/tennis1_kfj26a',
        'rallyup/courts/santa_clara_tennis_center/tennis3_ibkhhq',
      ],
    ),
    _SeedCourt(
      id: 'cupertino_sports_center',
      name: 'Cupertino Sports Center',
      sportTypes: ['Tennis', 'Badminton', 'Pickleball'],
      city: 'Cupertino',
      region: 'CA',
      address: 'Cupertino, CA',
      lat: 37.3230,
      lng: -122.0449,
      rating: 4.7,
      pricePerHour: 18,
      amenities: ['Indoor Courts', 'Parking', 'Restrooms'],
      description:
          'Multi-sport facility with tennis, badminton, and pickleball courts.',
      imagePublicIds: [
        'rallyup/courts/cupertino_sports_center/tenniscourt_nbauzj',
        'rallyup/courts/cupertino_sports_center/badmintoncourt_jgysct',
        'rallyup/courts/cupertino_sports_center/pickleballcourt_j1hl9i',
        'rallyup/courts/cupertino_sports_center/pickleballcourt2_kjy43h',
        'rallyup/courts/cupertino_sports_center/badmintoncourt2_vpwily',
      ],
    ),
    _SeedCourt(
      id: 'sunnyvale_indoor_sports_center',
      name: 'Sunnyvale Indoor Sports Center',
      sportTypes: ['Badminton', 'Table Tennis', 'Pickleball'],
      city: 'Sunnyvale',
      region: 'CA',
      address: 'Sunnyvale, CA',
      lat: 37.3625,
      lng: -122.0364,
      rating: 4.5,
      pricePerHour: 16,
      amenities: ['Indoor Courts', 'Parking', 'Equipment Rental'],
      description:
          'Indoor sports center for badminton, table tennis, and pickleball.',
      imagePublicIds: [
        'rallyup/courts/sunnyvale_indoor_sports_center/badmintoncourt_b9sffe',
        'rallyup/courts/sunnyvale_indoor_sports_center/tabletenniscourt_lf0hjd',
        'rallyup/courts/sunnyvale_indoor_sports_center/pickleballcourt_d6cemt',
        'rallyup/courts/sunnyvale_indoor_sports_center/pickleballcourt2_lkgbl6',
      ],
    ),
    _SeedCourt(
      id: 'san_jose_basketball_courts',
      name: 'San Jose Basketball Courts',
      sportTypes: ['Basketball'],
      city: 'San Jose',
      region: 'CA',
      address: 'San Jose, CA',
      lat: 37.3382,
      lng: -121.8863,
      rating: 4.4,
      pricePerHour: 10,
      amenities: ['Outdoor Courts', 'Parking', 'Lighting'],
      description:
          'Basketball courts for pickup games and casual play in San Jose.',
      imagePublicIds: [
        'rallyup/courts/san_jose_basketball_courts/basketballcourt_khqyf1',
        'rallyup/courts/san_jose_basketball_courts/basketballcourt2_nq8sn4',
      ],
    ),
    _SeedCourt(
      id: 'fremont_community_sports_courts',
      name: 'Fremont Community Sports Courts',
      sportTypes: ['Basketball', 'Volleyball', 'Badminton'],
      city: 'Fremont',
      region: 'CA',
      address: 'Fremont, CA',
      lat: 37.5485,
      lng: -121.9886,
      rating: 4.3,
      pricePerHour: 14,
      amenities: ['Community Courts', 'Parking', 'Restrooms'],
      description:
          'Community sports courts supporting basketball, volleyball, and badminton.',
      imagePublicIds: [
        'rallyup/courts/fremont_community_sports_courts/basketballcourt_l7egx8',
        'rallyup/courts/fremont_community_sports_courts/basketballcourt2_tcto2v',
        'rallyup/courts/fremont_community_sports_courts/volleyballcourt_slnswg',
        'rallyup/courts/fremont_community_sports_courts/volleyballcourt2_iwisft',
        'rallyup/courts/fremont_community_sports_courts/badmintoncourt_fvfo9z',
        'rallyup/courts/fremont_community_sports_courts/badmintoncourt2_hm1aw4',
      ],
    ),
    _SeedCourt(
      id: 'palo_alto_recreation_courts',
      name: 'Palo Alto Recreation Courts',
      sportTypes: ['Tennis', 'Pickleball', 'Basketball'],
      city: 'Palo Alto',
      region: 'CA',
      address: 'Palo Alto, CA',
      lat: 37.4419,
      lng: -122.1430,
      rating: 4.6,
      pricePerHour: 16,
      amenities: ['Parking', 'Lighting', 'Restrooms'],
      description:
          'Recreation courts for tennis, pickleball, and basketball in Palo Alto.',
      imagePublicIds: [
        'rallyup/courts/palo_alto_recreation_courts/tenniscourt_egcikp',
        'rallyup/courts/palo_alto_recreation_courts/tenniscourt2_i8ubey',
        'rallyup/courts/palo_alto_recreation_courts/pickleballcourt_ulgznp',
        'rallyup/courts/palo_alto_recreation_courts/basketballcourt_naouwo',
      ],
    ),
    _SeedCourt(
      id: 'milpitas_indoor_sports_complex',
      name: 'Milpitas Indoor Sports Complex',
      sportTypes: ['Badminton', 'Table Tennis', 'Volleyball'],
      city: 'Milpitas',
      region: 'CA',
      address: 'Milpitas, CA',
      lat: 37.4323,
      lng: -121.8996,
      rating: 4.5,
      pricePerHour: 17,
      amenities: ['Indoor Courts', 'Parking', 'Restrooms'],
      description:
          'Indoor sports complex for badminton, table tennis, and volleyball.',
      imagePublicIds: [
        'rallyup/courts/milpitas_indoor_sports_complex/badmintoncourt_hyoarh',
        'rallyup/courts/milpitas_indoor_sports_complex/tabletenniscourt_dnkeos',
        'rallyup/courts/milpitas_indoor_sports_complex/volleyballcourt_bkfmuw',
      ],
    ),
    _SeedCourt(
      id: 'santa_clara_soccer_field',
      name: 'Santa Clara Soccer Field',
      sportTypes: ['Soccer'],
      city: 'Santa Clara',
      region: 'CA',
      address: 'Santa Clara, CA',
      lat: 37.3541,
      lng: -121.9552,
      rating: 4.4,
      pricePerHour: 22,
      amenities: ['Outdoor Field', 'Parking', 'Lighting'],
      description:
          'Outdoor soccer field for casual and team play in Santa Clara.',
      imagePublicIds: [
        'rallyup/courts/santa_clara_soccer_field/soccercourt_brevw1',
        'rallyup/courts/santa_clara_soccer_field/soccercourt2_ilpmka',
      ],
    ),
    _SeedCourt(
      id: 'san_jose_cricket_ground',
      name: 'San Jose Cricket Ground',
      sportTypes: ['Cricket'],
      city: 'San Jose',
      region: 'CA',
      address: 'San Jose, CA',
      lat: 37.3382,
      lng: -121.8863,
      rating: 4.2,
      pricePerHour: 25,
      amenities: ['Outdoor Ground', 'Parking', 'Practice Nets'],
      description:
          'Cricket ground for practice sessions and friendly matches in San Jose.',
      imagePublicIds: [
        'rallyup/courts/san_jose_cricket_ground/cricketround_utyxlu',
        'rallyup/courts/san_jose_cricket_ground/cricketground2_jko2sr',
        'rallyup/courts/san_jose_cricket_ground/cricketground3_vlfrqf',
      ],
    ),
    _SeedCourt(
      id: 'mountain_view_multi_sport_park',
      name: 'Mountain View Multi-Sport Park',
      sportTypes: ['Soccer', 'Basketball', 'Volleyball', 'Tennis'],
      city: 'Mountain View',
      region: 'CA',
      address: 'Mountain View, CA',
      lat: 37.3861,
      lng: -122.0839,
      rating: 4.5,
      pricePerHour: 15,
      amenities: ['Multi-Sport Courts', 'Parking', 'Lighting', 'Restrooms'],
      description:
          'Multi-sport park with soccer, basketball, volleyball, and tennis facilities.',
      imagePublicIds: [
        'rallyup/courts/mountain_view_multi_sport_park/soccercourt_gtvpkr',
        'rallyup/courts/mountain_view_multi_sport_park/soccercourt2_ypw9l5',
        'rallyup/courts/mountain_view_multi_sport_park/soccercourt3_mxvtcw',
        'rallyup/courts/mountain_view_multi_sport_park/basketballcourt_z9vmfm',
        'rallyup/courts/mountain_view_multi_sport_park/volleyballcourt_sotenx',
        'rallyup/courts/mountain_view_multi_sport_park/tenniscourt_g2g2f7',
      ],
    ),
  ];
}

/// Seed row. Cloudinary public IDs are resolved to full URLs at
/// write time so the rest of the app never sees Cloudinary specifics.
class _SeedCourt {
  final String id;
  final String name;
  final List<String> sportTypes;
  final String city;
  final String region;
  final String address;
  final double lat;
  final double lng;
  final double rating;
  final double pricePerHour;
  final List<String> amenities;
  final String description;
  final List<String> imagePublicIds;

  const _SeedCourt({
    required this.id,
    required this.name,
    required this.sportTypes,
    required this.city,
    required this.region,
    required this.address,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.pricePerHour,
    required this.amenities,
    required this.description,
    required this.imagePublicIds,
  });

  Map<String, dynamic> toMapWithoutTimestamps(
    String Function(String publicId) urlBuilder,
  ) {
    return {
      'name': name,
      'sportTypes': sportTypes,
      'city': city,
      'region': region,
      'address': address,
      'lat': lat,
      'lng': lng,
      'rating': rating,
      'pricePerHour': pricePerHour,
      'amenities': amenities,
      'description': description,
      'imageUrls': imagePublicIds.map(urlBuilder).toList(),
      'isActive': true,
    };
  }
}
