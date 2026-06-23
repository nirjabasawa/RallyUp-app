import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/models/court.dart';
import 'package:rallyup/models/user_location.dart';
import 'package:rallyup/providers/auth_provider.dart';
import 'package:rallyup/screens/court_details_page.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/services/court_service.dart';
import 'package:rallyup/services/location_picker_handler.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/sport_emoji.dart';
import '../widgets/courts/court_listing_card.dart';
import '../widgets/courts/court_search_bar.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/notification_bell_button.dart';
import '../widgets/side_menu_drawer.dart';
import '../widgets/sports_card.dart';

class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  final CourtService _courtService = CourtService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedSport = 'All';
  String _selectedSort = 'default';

  static const List<String> _sports = [
    'Tennis',
    'Badminton',
    'Table Tennis',
    'Basketball',
    'Volleyball',
    'Pickleball',
    'Soccer',
    'Football',
    'Cricket',
    'Swimming',
  ];

  /// Sport via `sportTypes.contains(...)` (multi-sport venues
  /// surface for every supported sport), then search across name /
  /// city / sports, then sort by the current key.
  List<_RankedCourt> _filterAndSort(
    List<Court> courts,
    UserLocation? myLocation,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = courts.where((court) {
      final matchesSport =
          _selectedSport == 'All' ||
          court.sportTypes.any(
            (s) => s.toLowerCase() == _selectedSport.toLowerCase(),
          );

      final matchesSearch =
          query.isEmpty ||
          court.name.toLowerCase().contains(query) ||
          court.city.toLowerCase().contains(query) ||
          court.sportTypes.any((s) => s.toLowerCase().contains(query));

      return matchesSport && matchesSearch;
    });

    final ranked = filtered
        .map((c) => _RankedCourt.from(c, myLocation))
        .toList();

    switch (_selectedSort) {
      case 'distance':
        ranked.sort((a, b) {
          if (a.sameCity != b.sameCity) return a.sameCity ? -1 : 1;
          final aD = a.distanceKm ?? double.infinity;
          final bD = b.distanceKm ?? double.infinity;
          return aD.compareTo(bD);
        });
        break;
      case 'rating':
        ranked.sort((a, b) {
          final ar = a.court.rating ?? 0;
          final br = b.court.rating ?? 0;
          return br.compareTo(ar);
        });
        break;
      case 'price_low':
        ranked.sort(
          (a, b) => a.court.pricePerHour.compareTo(b.court.pricePerHour),
        );
        break;
      case 'default':
      default:
        // Default: same-city → nearest.
        ranked.sort((a, b) {
          if (a.sameCity != b.sameCity) return a.sameCity ? -1 : 1;
          final aD = a.distanceKm ?? double.infinity;
          final bD = b.distanceKm ?? double.infinity;
          return aD.compareTo(bD);
        });
    }
    return ranked;
  }

  /// "Tennis", "Tennis +1", "Tennis +2", … — compact enough to
  /// stay on the metadata row without pushing the price column.
  String _multiSportLabel(List<String> sportTypes, {required String primary}) {
    if (sportTypes.isEmpty) return primary;
    if (sportTypes.length == 1) return sportTypes.first;
    final remaining = sportTypes
        .where((s) => s.toLowerCase() != primary.toLowerCase())
        .length;
    if (remaining <= 0) return primary;
    return '$primary +$remaining';
  }

  String _getSportImagePath(String sport) {
    switch (sport) {
      case 'Tennis':
        return 'assets/images/sports/tennis.png';
      case 'Badminton':
        return 'assets/images/sports/badminton.png';
      case 'Table Tennis':
        return 'assets/images/sports/table_tennis.png';
      case 'Basketball':
        return 'assets/images/sports/basketball.png';
      case 'Volleyball':
        return 'assets/images/sports/volleyball.png';
      case 'Pickleball':
        return 'assets/images/sports/pickleball.png';
      case 'Soccer':
        return 'assets/images/sports/soccer.png';
      case 'Football':
        return 'assets/images/sports/football.png';
      case 'Cricket':
        return 'assets/images/sports/cricket.png';
      case 'Swimming':
        return 'assets/images/sports/swimming.png';
      default:
        return '';
    }
  }

  Future<void> _openLocationOverlay() => openLocationPicker(context);

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sort & Filter',
                style: AppTextStyles.sectionTitle.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              _FilterOptionTile(
                title: 'Default',
                isSelected: _selectedSort == 'default',
                onTap: () {
                  setState(() => _selectedSort = 'default');
                  Navigator.pop(context);
                },
              ),
              _FilterOptionTile(
                title: 'Nearest Distance',
                isSelected: _selectedSort == 'distance',
                onTap: () {
                  setState(() => _selectedSort = 'distance');
                  Navigator.pop(context);
                },
              ),
              _FilterOptionTile(
                title: 'Highest Rating',
                isSelected: _selectedSort == 'rating',
                onTap: () {
                  setState(() => _selectedSort = 'rating');
                  Navigator.pop(context);
                },
              ),
              _FilterOptionTile(
                title: 'Lowest Price',
                isSelected: _selectedSort == 'price_low',
                onTap: () {
                  setState(() => _selectedSort = 'price_low');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openCourtDetails(Court court, String distanceText) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) =>
            CourtDetailsPage(court: court, distanceText: distanceText),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switchToMainShellTab(context, index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final myLocation = me?.location;
    final locationLabel = myLocation?.displayLabel ?? 'Set location';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SideMenuDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                18,
                AppSpacing.pageHorizontal,
                6,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          return IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.menu_rounded,
                              size: 34,
                              color: AppColors.textPrimary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 18),
                      Text(
                        'Courts',
                        style: AppTextStyles.pageTitle.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      const NotificationBellButton(size: 30),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _openLocationOverlay,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            locationLabel,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CourtSearchBar(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    onFilterTap: _openFilterSheet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _sports.length + 1,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return SportsCard(
                      isAllCard: true,
                      isSelected: _selectedSport == 'All',
                      onTap: () => setState(() => _selectedSport = 'All'),
                    );
                  }
                  final sport = _sports[index - 1];
                  return SportsCard(
                    imagePath: _getSportImagePath(sport),
                    isSelected: _selectedSport == sport,
                    onTap: () => setState(() => _selectedSport = sport),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Court>>(
                stream: _courtService.streamActiveCourts(),
                builder: (context, snapshot) {
                  final waitingFirst =
                      snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
                  if (waitingFirst) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final courts = _filterAndSort(
                    snapshot.data ?? const [],
                    myLocation,
                  );
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: Text(
                          'Nearby Courts',
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (courts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageHorizontal,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Text(
                                    'No courts found',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Try another sport or search term',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ...courts.map((ranked) {
                          final court = ranked.court;
                          // Use the selected sport's emoji when the
                          // court supports it.
                          final emojiSport =
                              _selectedSport != 'All' &&
                                  court.sportTypes.any(
                                    (s) =>
                                        s.toLowerCase() ==
                                        _selectedSport.toLowerCase(),
                                  )
                              ? _selectedSport
                              : (court.sportTypes.isNotEmpty
                                    ? court.sportTypes.first
                                    : 'Tennis');
                          // Multi-sport label leads with the active
                          // sport and appends "+N" for the rest, so
                          // other sports entirely.
                          final sportsLabel = _multiSportLabel(
                            court.sportTypes,
                            primary: emojiSport,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: CourtListingCard(
                              imageUrl: court.imageUrls.isNotEmpty
                                  ? court.imageUrls.first
                                  : null,
                              title: court.name,
                              sportsLabel: sportsLabel,
                              sportEmoji: sportEmojiFor(emojiSport),
                              distanceText: ranked.distanceText,
                              ratingText: (court.rating ?? 0).toStringAsFixed(
                                1,
                              ),
                              priceText:
                                  '\$${court.pricePerHour.toStringAsFixed(0)}/hr',
                              onViewDetailsTap: () =>
                                  _openCourtDetails(court, ranked.distanceText),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

class _FilterOptionTile extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOptionTile({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Pairs a Court with its computed-distance display so the row in the
/// stream's `.map` doesn't have to plumb both around separately. Kept
/// private — moves to a shared place the moment another screen needs
/// the same shape.
class _RankedCourt {
  final Court court;
  final double? distanceKm;
  final bool sameCity;

  const _RankedCourt({
    required this.court,
    required this.distanceKm,
    required this.sameCity,
  });

  factory _RankedCourt.from(Court court, UserLocation? me) {
    if (me == null) {
      return _RankedCourt(court: court, distanceKm: null, sameCity: false);
    }
    return _RankedCourt(
      court: court,
      distanceKm: _haversineKm(me.lat, me.lng, court.lat, court.lng),
      sameCity:
          me.city.isNotEmpty &&
          me.city.toLowerCase() == court.city.toLowerCase(),
    );
  }

  String get distanceText {
    if (distanceKm == null) {
      // No user location → fall back to the court's city so the row
      // never reads as a bare empty distance.
      return court.city;
    }
    final mi = distanceKm! * 0.621371;
    if (mi < 0.1) return '< 0.1 mi';
    return '${mi.toStringAsFixed(1)} mi';
  }
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  double toRad(double d) => d * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}
