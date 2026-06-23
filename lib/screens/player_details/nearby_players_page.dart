import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/models/app_user.dart';
import 'package:rallyup/models/user_location.dart';
import 'package:rallyup/providers/auth_provider.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/screens/player_details/message_page.dart';
import 'package:rallyup/screens/player_details/player_profile_page.dart';
import 'package:rallyup/services/location_picker_handler.dart';
import 'package:rallyup/services/user_service.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/courts/court_search_bar.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/player_details/player_details_components.dart';
import '../../widgets/side_menu_drawer.dart';
import '../../widgets/sports_card.dart';

class NearbyPlayersPage extends StatefulWidget {
  const NearbyPlayersPage({super.key});

  @override
  State<NearbyPlayersPage> createState() => _NearbyPlayersPageState();
}

class _NearbyPlayersPageState extends State<NearbyPlayersPage> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();

  String _selectedSport = 'All';
  String _selectedSort = 'default';

  static const List<String> _sports = ['Tennis', 'Badminton', 'Table Tennis'];

  String _getSportImagePath(String sport) {
    switch (sport) {
      case 'Tennis':
        return 'assets/images/sports/tennis.png';
      case 'Badminton':
        return 'assets/images/sports/badminton.png';
      case 'Table Tennis':
        return 'assets/images/sports/table_tennis.png';
      default:
        return '';
    }
  }

  Future<void> _openLocationOverlay() => openLocationPicker(context);

  void _openPlayerProfile(_RankedPlayer ranked) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => PlayerProfilePage(
          user: ranked.user,
          distance: ranked.distanceLabel,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openPersonalChat(_RankedPlayer ranked) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MessagePage(otherUser: ranked.user),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _onBottomNavTap(int index) {
    switchToMainShellTab(context, index);
  }

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
                title: 'Name A-Z',
                isSelected: _selectedSort == 'name',
                onTap: () {
                  setState(() => _selectedSort = 'name');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _primarySport(AppUser u) {
    if (u.sports.isEmpty) return 'Multi-sport';
    return u.sports.first;
  }

  List<_RankedPlayer> _rankAndFilter(
    List<AppUser> users,
    UserLocation? myLocation,
  ) {
    final query = _searchController.text.trim().toLowerCase();

    final ranked = users
        .where((u) {
          final matchesSearch =
              query.isEmpty ||
              u.displayName.toLowerCase().contains(query) ||
              u.sports.any((s) => s.toLowerCase().contains(query));

          final matchesSport =
              _selectedSport == 'All' ||
              u.sports.any(
                (s) => s.toLowerCase() == _selectedSport.toLowerCase(),
              );

          return matchesSearch && matchesSport;
        })
        .map((u) => _RankedPlayer.from(u, myLocation))
        .toList();

    // Adjustment #3 — name sort and distance sort are mutually exclusive:
    // use a single if/else so the chosen sort isn't immediately overwritten.
    if (_selectedSort == 'name') {
      ranked.sort((a, b) => a.user.displayName.compareTo(b.user.displayName));
    } else {
      // Default + distance ordering: same-city players first (so a Santa
      // Clara user sees other Santa Clara users at the top), then nearest
      // by great-circle distance. Players without a location sink to the
      // bottom because their distance is `infinity`.
      ranked.sort((a, b) {
        if (a.sameCity != b.sameCity) return a.sameCity ? -1 : 1;
        final ad = a.distanceKm ?? double.infinity;
        final bd = b.distanceKm ?? double.infinity;
        return ad.compareTo(bd);
      });
    }

    return ranked;
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final myLocation = me?.location;
    final locationLabel = myLocation?.displayLabel ?? 'Set location';

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const SideMenuDrawer(),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: _onBottomNavTap,
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppUser>>(
          stream: _userService.streamAllUsers(excludeUid: me?.uid),
          builder: (context, snapshot) {
            final users = snapshot.data ?? const <AppUser>[];
            final players = _rankAndFilter(users, myLocation);
            final waitingForFirstSnapshot =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pageHorizontal,
                    18,
                    AppSpacing.pageHorizontal,
                    8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              return IconButton(
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
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
                            'Nearby Players',
                            style: AppTextStyles.pageTitle.copyWith(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          const NotificationBellButton(size: 30),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _openLocationOverlay,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${players.length} players nearby',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                locationLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CourtSearchBar(
                        controller: _searchController,
                        hintText: 'Search nearby players',
                        onChanged: (_) => setState(() {}),
                        onFilterTap: _openFilterSheet,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
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
                          onTap: () {
                            setState(() {
                              _selectedSport = 'All';
                            });
                          },
                        );
                      }

                      final sport = _sports[index - 1];

                      return SportsCard(
                        imagePath: _getSportImagePath(sport),
                        isSelected: _selectedSport == sport,
                        onTap: () {
                          setState(() {
                            _selectedSport = sport;
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Players Near You',
                              style: AppTextStyles.sectionTitle,
                            ),
                            const Spacer(),
                            Text(
                              '${players.length} found',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: waitingForFirstSnapshot
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : players.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Center(
                                  child: Text(
                                    'No players found for this search/filter',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final ranked in players) ...[
                                    PlayerDetailsPlayerCard(
                                      name: ranked.user.displayName,
                                      initials: ranked.user.initials,
                                      photoUrl: ranked.user.photoUrl,
                                      avatarId: ranked.user.avatarId,
                                      sport: _primarySport(ranked.user),
                                      distance: ranked.distanceLabel,
                                      bio: ranked.user.bio?.isNotEmpty == true
                                          ? ranked.user.bio!
                                          : (ranked.sameCity
                                                ? 'Plays in '
                                                      '${ranked.user.location!.city}'
                                                : 'Open to nearby matches'),
                                      actionLabel: 'Connect',
                                      rating: 4.8,
                                      onViewProfileTap: () =>
                                          _openPlayerProfile(ranked),
                                      onActionTap: () =>
                                          _openPersonalChat(ranked),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                  Text(
                                    '${players.length} players shown',
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// View model that pairs an [AppUser] with the distance-from-me bookkeeping
/// the list needs for ranking and label rendering. Kept private to this
/// page — the moment a second screen needs it, it should graduate to its
/// own file.
class _RankedPlayer {
  final AppUser user;
  final double? distanceKm;
  final bool sameCity;

  const _RankedPlayer({
    required this.user,
    required this.distanceKm,
    required this.sameCity,
  });

  factory _RankedPlayer.from(AppUser u, UserLocation? me) {
    if (me == null || u.location == null) {
      return _RankedPlayer(user: u, distanceKm: null, sameCity: false);
    }
    return _RankedPlayer(
      user: u,
      distanceKm: _haversineKm(
        me.lat,
        me.lng,
        u.location!.lat,
        u.location!.lng,
      ),
      sameCity:
          u.location!.city.isNotEmpty &&
          u.location!.city.toLowerCase() == me.city.toLowerCase(),
    );
  }

  /// Distance label shown on the player card. Adjustment #6 — when we have
  /// no usable distance (either we don't know our own location, or the
  /// other user has none), fall back to that user's own location label so
  /// the card never reads as a bare "No distance". If they have no
  /// location either, fall back to the displayLabel default.
  String get distanceLabel {
    if (distanceKm == null) {
      return user.location?.displayLabel ?? 'Location unavailable';
    }
    final mi = distanceKm! * 0.621371;
    if (mi < 0.1) return '< 0.1 mi';
    return '${mi.toStringAsFixed(1)} mi';
  }
}

/// Great-circle distance in kilometres between two lat/lng pairs.
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
