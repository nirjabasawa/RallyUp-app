import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/main.dart';
import 'package:intl/intl.dart';
import 'package:rallyup/models/app_user.dart';
import 'package:rallyup/models/booking.dart';
import 'package:rallyup/models/court.dart';
import 'package:rallyup/models/open_match.dart';
import 'package:rallyup/models/user_location.dart';
import 'package:rallyup/providers/auth_provider.dart';
import 'package:rallyup/screens/booking_confirmed_page.dart';
import 'package:rallyup/screens/court_details_page.dart';
import 'package:rallyup/screens/courts_page.dart';
import 'package:rallyup/screens/my_bookings_page.dart';
import 'package:rallyup/screens/player_details/match_details_page.dart';
import 'package:rallyup/screens/player_details/nearby_players_page.dart';
import 'package:rallyup/screens/player_details/open_matches_page.dart';
import 'package:rallyup/screens/player_details/player_profile_page.dart';
import 'package:rallyup/screens/profile/subscription_screen.dart';
import 'package:rallyup/screens/logout_helper.dart';
import 'package:rallyup/services/booking_service.dart';
import 'package:rallyup/services/court_service.dart';
import 'package:rallyup/services/location_picker_handler.dart';
import 'package:rallyup/services/location_service.dart';
import 'package:rallyup/services/open_match_service.dart';
import 'package:rallyup/services/user_service.dart';
import 'package:rallyup/utils/sport_emoji.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/booking_preview_card.dart';
import '../../widgets/home/home_nearby_player_preview_card.dart';
import '../../widgets/home/home_section_header.dart';
import '../../widgets/home/home_suggested_court_preview_card.dart';
import '../../widgets/home/home_suggested_open_match_preview_card.dart';
import '../../widgets/home_top_header.dart';
import '../../widgets/sports_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedSport = 'All';

  final LocationService _locationService = LocationService();
  final UserService _userService = UserService();
  final CourtService _courtService = CourtService();
  final BookingService _bookingService = BookingService();
  final OpenMatchService _openMatchService = OpenMatchService();
  bool _locationCaptureStarted = false;

  // "View all" routes to the full NearbyPlayersPage.
  static const int _homeNearbyPreviewLimit = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoFetchLocation();
    });
  }

  /// Fires once per HomePage lifetime when the user has no location
  /// yet. Permission denial is silent — they can tap the chip to retry.
  Future<void> _maybeAutoFetchLocation() async {
    if (_locationCaptureStarted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || user.location != null) return;
    _locationCaptureStarted = true;
    try {
      final captured = await _locationService.captureCurrent();
      if (!mounted) return;
      await auth.updateLocation(captured);
    } catch (_) {
      // Permission denied / service off — leave the "Set location"
      // fallback in place.
    }
  }

  final List<String> _sports = const [
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

  /// Same ranking as NearbyPlayersPage: selected-sport first, then
  /// same-city, then nearest. Excludes the current user.
  List<_HomeRankedPlayer> _rankForHome(
    List<AppUser> users,
    UserLocation? myLocation,
  ) {
    final filtered = _selectedSport == 'All'
        ? users
        : users
              .where(
                (u) => u.sports.any(
                  (s) => s.toLowerCase() == _selectedSport.toLowerCase(),
                ),
              )
              .toList();
    final ranked =
        filtered.map((u) => _HomeRankedPlayer.from(u, myLocation)).toList()
          ..sort((a, b) {
            if (a.sameCity != b.sameCity) return a.sameCity ? -1 : 1;
            final aD = a.distanceKm ?? double.infinity;
            final bD = b.distanceKm ?? double.infinity;
            return aD.compareTo(bD);
          });
    return ranked.length > _homeNearbyPreviewLimit
        ? ranked.sublist(0, _homeNearbyPreviewLimit)
        : ranked;
  }

  String _primarySport(AppUser u) =>
      u.sports.isEmpty ? 'Multi-sport' : u.sports.first;

  void _openPlayerProfileFromHome(_HomeRankedPlayer ranked) {
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

  /// Same-city → nearest ranking for the Suggested Courts rail.
  /// `sportTypes.contains(...)` so multi-sport venues match every
  /// supported sport, not just the primary.
  List<_HomeRankedCourt> _rankCourts(
    List<Court> courts,
    UserLocation? myLocation,
  ) {
    final filtered = _selectedSport == 'All'
        ? courts
        : courts
              .where(
                (c) => c.sportTypes.any(
                  (s) => s.toLowerCase() == _selectedSport.toLowerCase(),
                ),
              )
              .toList();
    final ranked =
        filtered.map((c) => _HomeRankedCourt.from(c, myLocation)).toList()
          ..sort((a, b) {
            if (a.sameCity != b.sameCity) return a.sameCity ? -1 : 1;
            final aD = a.distanceKm ?? double.infinity;
            final bD = b.distanceKm ?? double.infinity;
            return aD.compareTo(bD);
          });
    const homeCourtsLimit = 6;
    return ranked.length > homeCourtsLimit
        ? ranked.sublist(0, homeCourtsLimit)
        : ranked;
  }

  /// Hides cancelled, full, past, host's own, and already-joined
  /// matches. Capped to six.
  List<OpenMatch> _rankOpenMatchesForHome(
    List<OpenMatch> matches,
    String? currentUid,
  ) {
    final now = DateTime.now();
    final filtered = matches.where((m) {
      if (m.isCancelled) return false;
      if (m.isFull) return false;
      // Drop already-ended matches. Combine `date` + `endTime` so a
      // 5–6 PM match disappears at 6 PM, not at midnight.
      final endParts = m.endTime.split(':');
      final endH = int.tryParse(endParts.isNotEmpty ? endParts[0] : '') ?? 0;
      final endMin = int.tryParse(endParts.length > 1 ? endParts[1] : '') ?? 0;
      final endsAt = DateTime(
        m.date.year,
        m.date.month,
        m.date.day,
        endH,
        endMin,
      );
      if (!endsAt.isAfter(now)) return false;
      if (currentUid != null) {
        if (m.hostUid == currentUid) return false;
        if (m.joinedPlayerIds.contains(currentUid)) return false;
      }
      if (_selectedSport != 'All' &&
          m.sportType.toLowerCase() != _selectedSport.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
    const homeMatchesLimit = 6;
    return filtered.length > homeMatchesLimit
        ? filtered.sublist(0, homeMatchesLimit)
        : filtered;
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

  Future<void> _performLogout(BuildContext context) async {
    await performLogout(context);
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF4A4A4A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Log out?',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.white,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Are you sure you want\nto logout of your\naccount?',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.white),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _performLogout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _openProfilePage() {
    // Switch the existing MainShell rather than pushing a new one —
    // that would pop AuthGate off the stack and break sign-out.
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.globalKey.currentState?.switchTo(2);
  }

  void _openMembershipPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const SubscriptionScreen(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openProfileOptionsOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              top: 82,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromARGB(18, 0, 0, 0),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ProfileOptionTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Profile',
                        onTap: () {
                          Navigator.pop(context);
                          _openProfilePage();
                        },
                      ),
                      _ProfileOptionTile(
                        icon: Icons.card_membership_rounded,
                        title: 'Membership',
                        onTap: () {
                          Navigator.pop(context);
                          _openMembershipPage();
                        },
                      ),
                      const Divider(height: 1),
                      _ProfileOptionTile(
                        icon: Icons.logout_rounded,
                        title: 'Sign Out',
                        isDanger: true,
                        onTap: () {
                          Navigator.pop(context);
                          _showLogoutDialog(this.context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openLocationOverlay() => openLocationPicker(context);

  void _openMyBookingsPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const MyBookingsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openNearbyPlayersPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NearbyPlayersPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openCourtsPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const CourtsPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openOpenMatchesPage() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const OpenMatchesPage(),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Combines `date` + `endTime` so a still-running booking stays in
  /// the rail until its actual end. Matches MyBookingsPage's rule.
  DateTime _bookingEndDateTime(Booking booking) {
    final parts = booking.endTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(
      booking.date.year,
      booking.date.month,
      booking.date.day,
      h,
      m,
    );
  }

  DateTime _matchEndDateTime(OpenMatch match) {
    final parts = match.endTime.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return DateTime(match.date.year, match.date.month, match.date.day, h, m);
  }

  String _fmtClock(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
  }

  void _openBookingDetails(Booking booking) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => BookingConfirmedPage(booking: booking),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Booking → BookingConfirmedPage; match → MatchDetailsPage.
  /// Same routing as MyBookings.
  void _openHomeBookingRow(_HomeBookingRow row) {
    final booking = row.booking;
    final match = row.match;
    if (booking != null) {
      _openBookingDetails(booking);
    } else if (match != null) {
      _openMatchDetailsPage(match);
    }
  }

  void _openCourtDetails(_HomeRankedCourt ranked) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => CourtDetailsPage(
          court: ranked.court,
          distanceText: ranked.distanceText,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openMatchDetailsPage(OpenMatch match) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MatchDetailsPage(match: match),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    // Same rationale as profile_page: render nothing while AuthGate is
    // about to swap us out for SignupScreen. SizedBox.shrink() (instead
    // of an opaque Scaffold) makes this a non-event visually — if this
    // build happens to land before AuthGate's repaint, the user never
    // sees a blank background page.
    if (currentUser == null) {
      return const SizedBox.shrink();
    }
    final firstName = currentUser.firstName;
    final initials = currentUser.initials;
    final avatarId = currentUser.avatarId;
    final locationLabel = currentUser.location?.displayLabel ?? 'Set location';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            HomeTopHeader(
              firstName: firstName,
              initials: initials,
              avatarId: avatarId,
              photoUrl: currentUser.photoUrl,
              locationText: locationLabel,
              onProfileTap: _openProfileOptionsOverlay,
              onLocationTap: _openLocationOverlay,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('All Sports', style: AppTextStyles.sectionTitle),
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  HomeSectionHeader(
                    title: 'My Bookings',
                    onViewAllTap: _openMyBookingsPage,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 232,
                    child: StreamBuilder<List<Booking>>(
                      stream: _bookingService.streamBookingsForUser(
                        currentUser.uid,
                      ),
                      builder: (context, bookingSnap) {
                        return StreamBuilder<List<OpenMatch>>(
                          stream: _openMatchService.streamMatchesForUser(
                            currentUser.uid,
                          ),
                          builder: (context, matchSnap) {
                            // Only show the spinner while BOTH streams are
                            // still waiting on their first frame — once
                            // either side has data we render partial
                            // results instead of blocking.
                            final bothWaiting =
                                bookingSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !bookingSnap.hasData &&
                                matchSnap.connectionState ==
                                    ConnectionState.waiting &&
                                !matchSnap.hasData;
                            if (bothWaiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final now = DateTime.now();
                            final bookings =
                                bookingSnap.data ?? const <Booking>[];
                            final matches =
                                matchSnap.data ?? const <OpenMatch>[];

                            final rows = <_HomeBookingRow>[];

                            // Confirmed + still in the future. Same
                            // rule as MyBookings.
                            for (final b in bookings) {
                              if (b.isCancelled) continue;
                              if (!b.isConfirmed) continue;
                              final endsAt = _bookingEndDateTime(b);
                              if (!endsAt.isAfter(now)) continue;
                              rows.add(
                                _HomeBookingRow(
                                  endsAt: endsAt,
                                  startTime: b.startTime,
                                  sportType: b.sportType,
                                  booking: b,
                                ),
                              );
                            }

                            // Hosted or joined, not cancelled, still
                            // in the future.
                            for (final m in matches) {
                              if (m.isCancelled) continue;
                              final isHost = m.hostUid == currentUser.uid;
                              final isJoined = m.joinedPlayerIds.contains(
                                currentUser.uid,
                              );
                              if (!isHost && !isJoined) continue;
                              final endsAt = _matchEndDateTime(m);
                              if (!endsAt.isAfter(now)) continue;
                              rows.add(
                                _HomeBookingRow(
                                  endsAt: endsAt,
                                  startTime: m.startTime,
                                  sportType: m.sportType,
                                  match: m,
                                ),
                              );
                            }

                            // Sport chip filter runs after the
                            // upcoming filter so the "All" view stays
                            // complete.
                            final filtered = _selectedSport == 'All'
                                ? rows
                                : rows
                                      .where(
                                        (r) =>
                                            r.sportType.toLowerCase() ==
                                            _selectedSport.toLowerCase(),
                                      )
                                      .toList();
                            // Soonest end-time first.
                            filtered.sort((a, b) {
                              final byEnd = a.endsAt.compareTo(b.endsAt);
                              if (byEnd != 0) return byEnd;
                              return a.startTime.compareTo(b.startTime);
                            });
                            final preview = filtered.take(6).toList();

                            if (preview.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.pageHorizontal,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'No bookings yet',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Book a court to see it here',
                                          style: AppTextStyles.bodyMedium
                                              .copyWith(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.pageHorizontal,
                              ),
                              scrollDirection: Axis.horizontal,
                              itemCount: preview.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 16),
                              itemBuilder: (context, index) {
                                final row = preview[index];
                                final dateText = DateFormat(
                                  'EEE, MMM d',
                                ).format(row.date);
                                final timeText =
                                    '${_fmtClock(context, row.startTime)}'
                                    ' - '
                                    '${_fmtClock(context, row.endTime)}';
                                return BookingPreviewCard(
                                  imageUrl: row.imageUrl,
                                  title: row.title,
                                  sport:
                                      '${sportEmojiFor(row.sportType)}  '
                                      '${row.sportType}',
                                  dateText: dateText,
                                  timeText: timeText,
                                  onTap: () => _openHomeBookingRow(row),
                                  onViewDetailsTap: () =>
                                      _openHomeBookingRow(row),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  HomeSectionHeader(
                    title: 'Nearby Players',
                    onViewAllTap: _openNearbyPlayersPage,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 134,
                    child: StreamBuilder<List<AppUser>>(
                      stream: _userService.streamAllUsers(
                        excludeUid: currentUser.uid,
                      ),
                      builder: (context, snapshot) {
                        final waitingFirst =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        if (waitingFirst) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final ranked = _rankForHome(
                          snapshot.data ?? const <AppUser>[],
                          currentUser.location,
                        );
                        if (ranked.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pageHorizontal,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  'No nearby players for this sport',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageHorizontal,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: ranked.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final r = ranked[index];
                            final subtitleParts = <String>[
                              _primarySport(r.user),
                              r.distanceLabel,
                            ].where((s) => s.isNotEmpty).toList();
                            return HomeNearbyPlayerPreviewCard(
                              name: r.user.displayName,
                              subtitle: subtitleParts.join('  •  '),
                              initials: r.user.initials,
                              photoUrl: r.user.photoUrl,
                              avatarId: r.user.avatarId,
                              onConnectTap: () => _openPlayerProfileFromHome(r),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  HomeSectionHeader(
                    title: 'Suggested Courts',
                    onViewAllTap: _openCourtsPage,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 246,
                    child: StreamBuilder<List<Court>>(
                      stream: _courtService.streamActiveCourts(),
                      builder: (context, snapshot) {
                        final waitingFirst =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        if (waitingFirst) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final ranked = _rankCourts(
                          snapshot.data ?? const <Court>[],
                          currentUser.location,
                        );
                        if (ranked.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pageHorizontal,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  'No suggested courts for this sport',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageHorizontal,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: ranked.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final r = ranked[index];
                            // Use the court's first sport when the
                            // selected one isn't supported so the
                            // label is never misleading.
                            final sportLabel =
                                _selectedSport != 'All' &&
                                    r.court.sportTypes.any(
                                      (s) =>
                                          s.toLowerCase() ==
                                          _selectedSport.toLowerCase(),
                                    )
                                ? _selectedSport
                                : (r.court.sportTypes.isNotEmpty
                                      ? r.court.sportTypes.first
                                      : 'Tennis');
                            return HomeSuggestedCourtPreviewCard(
                              imageUrl: r.court.imageUrls.isNotEmpty
                                  ? r.court.imageUrls.first
                                  : null,
                              sport:
                                  '${sportEmojiFor(sportLabel)}  $sportLabel',
                              distanceText: r.distanceText,
                              ratingText: (r.court.rating ?? 0).toStringAsFixed(
                                1,
                              ),
                              onViewDetailsTap: () => _openCourtDetails(r),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 26),
                  HomeSectionHeader(
                    title: 'Suggested Open Matches',
                    onViewAllTap: _openOpenMatchesPage,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 252,
                    child: StreamBuilder<List<OpenMatch>>(
                      stream: _openMatchService.streamOpenMatches(),
                      builder: (context, snapshot) {
                        final waitingFirst =
                            snapshot.connectionState ==
                                ConnectionState.waiting &&
                            !snapshot.hasData;
                        if (waitingFirst) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final matches = _rankOpenMatchesForHome(
                          snapshot.data ?? const <OpenMatch>[],
                          currentUser.uid,
                        );
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pageHorizontal,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Center(
                                child: Text(
                                  _selectedSport == 'All'
                                      ? 'No open matches yet'
                                      : 'No open matches for this sport',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pageHorizontal,
                          ),
                          scrollDirection: Axis.horizontal,
                          itemCount: matches.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 16),
                          itemBuilder: (context, index) {
                            final m = matches[index];
                            final dateText = DateFormat(
                              'EEE, MMM d',
                            ).format(m.date);
                            final timeText = _fmtClock(context, m.startTime);
                            final emoji = sportEmojiFor(m.sportType);
                            return HomeSuggestedOpenMatchPreviewCard(
                              imageUrl: m.courtImageUrl.isEmpty
                                  ? null
                                  : m.courtImageUrl,
                              title: m.courtName,
                              sport: '$emoji  ${m.sportType}',
                              players: '${m.joinedCount}/${m.playersRequired}',
                              dateText: dateText,
                              timeText: timeText,
                              onViewDetailsTap: () => _openMatchDetailsPage(m),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified Home-rail row. Exactly one of [booking] or [match] is
/// non-null. Letting both shapes share one list keeps private
/// bookings and open matches interleaved by end time without
/// merging the two Firestore collections.
class _HomeBookingRow {
  final DateTime endsAt;
  final String startTime;
  final String sportType;
  final Booking? booking;
  final OpenMatch? match;

  _HomeBookingRow({
    required this.endsAt,
    required this.startTime,
    required this.sportType,
    this.booking,
    this.match,
  });

  DateTime get date => booking?.date ?? match!.date;
  String get endTime => booking?.endTime ?? match!.endTime;
  String get title => booking?.courtName ?? match!.courtName;
  String? get imageUrl {
    final b = booking;
    if (b != null) return b.courtImageUrl;
    final m = match!;
    return m.courtImageUrl.isEmpty ? null : m.courtImageUrl;
  }
}

class _ProfileOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDanger;
  final VoidCallback onTap;

  const _ProfileOptionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AppUser + pre-computed distance bookkeeping for the home preview.
/// Mirrors NearbyPlayersPage's private `_RankedPlayer`.
class _HomeRankedPlayer {
  final AppUser user;
  final double? distanceKm;
  final bool sameCity;

  const _HomeRankedPlayer({
    required this.user,
    required this.distanceKm,
    required this.sameCity,
  });

  factory _HomeRankedPlayer.from(AppUser u, UserLocation? me) {
    if (me == null || u.location == null) {
      return _HomeRankedPlayer(user: u, distanceKm: null, sameCity: false);
    }
    return _HomeRankedPlayer(
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

  String get distanceLabel {
    if (distanceKm == null) {
      return user.location?.displayLabel ?? 'Location unavailable';
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

/// Court-side analogue of [_HomeRankedPlayer]. Carries the
/// pre-computed distance label so we don't redo haversine per render.
class _HomeRankedCourt {
  final Court court;
  final double? distanceKm;
  final bool sameCity;

  const _HomeRankedCourt({
    required this.court,
    required this.distanceKm,
    required this.sameCity,
  });

  factory _HomeRankedCourt.from(Court court, UserLocation? me) {
    if (me == null) {
      return _HomeRankedCourt(court: court, distanceKm: null, sameCity: false);
    }
    return _HomeRankedCourt(
      court: court,
      distanceKm: _haversineKm(me.lat, me.lng, court.lat, court.lng),
      sameCity:
          me.city.isNotEmpty &&
          me.city.toLowerCase() == court.city.toLowerCase(),
    );
  }

  String get distanceText {
    if (distanceKm == null) return court.city;
    final mi = distanceKm! * 0.621371;
    if (mi < 0.1) return '< 0.1 mi away';
    return '${mi.toStringAsFixed(1)} mi away';
  }
}
