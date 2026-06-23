import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rallyup/providers/auth_provider.dart';
import 'package:rallyup/screens/main_shell_nav.dart';
import 'package:rallyup/screens/player_details/match_details_page.dart';
import 'package:rallyup/services/location_picker_handler.dart';

import '../../models/open_match.dart';
import '../../services/open_match_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/sport_emoji.dart';
import '../../widgets/courts/court_search_bar.dart';
import '../../widgets/main_bottom_nav.dart';
import '../../widgets/notification_bell_button.dart';
import '../../widgets/side_menu_drawer.dart';
import '../../widgets/sports_card.dart';
import '../../widgets/player_details/open_matches/open_match_card.dart';

class OpenMatchesPage extends StatefulWidget {
  const OpenMatchesPage({super.key});

  @override
  State<OpenMatchesPage> createState() => _OpenMatchesPageState();
}

class _OpenMatchesPageState extends State<OpenMatchesPage> {
  final OpenMatchService _openMatchService = OpenMatchService();
  String _selectedSport = 'All';
  String _selectedSort = 'default';
  final TextEditingController _searchController = TextEditingController();

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

  /// Filters by sport + free-text search; hides cancelled, full,
  /// past, host-own, and already-joined matches. Sort keys:
  /// `slots`/`default` → most spots-left, `distance` → fewest
  /// spots-left, `rating` → most joined, `price_low` → cheapest
  /// per player.
  List<OpenMatch> _filterAndSort(List<OpenMatch> matches, String? currentUid) {
    final query = _searchController.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = matches.where((m) {
      if (m.isCancelled) return false;
      if (m.isFull) return false;
      // Drop already-ended matches by combining date + endTime.
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
      final matchesSport =
          _selectedSport == 'All' ||
          m.sportType.toLowerCase() == _selectedSport.toLowerCase();
      final matchesSearch =
          query.isEmpty ||
          m.courtName.toLowerCase().contains(query) ||
          m.hostName.toLowerCase().contains(query) ||
          m.sportType.toLowerCase().contains(query) ||
          m.courtAddress.toLowerCase().contains(query);
      return matchesSport && matchesSearch;
    }).toList();

    switch (_selectedSort) {
      case 'distance':
        filtered.sort((a, b) => a.spotsLeft.compareTo(b.spotsLeft));
        break;
      case 'rating':
        filtered.sort((a, b) => b.joinedCount.compareTo(a.joinedCount));
        break;
      case 'price_low':
        filtered.sort((a, b) => a.pricePerPlayer.compareTo(b.pricePerPlayer));
        break;
      case 'slots':
        filtered.sort((a, b) => b.spotsLeft.compareTo(a.spotsLeft));
        break;
      case 'default':
      default:
        // Soonest start first.
        break;
    }
    return filtered;
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
                title: 'Most Joined',
                isSelected: _selectedSort == 'rating',
                onTap: () {
                  setState(() => _selectedSort = 'rating');
                  Navigator.pop(context);
                },
              ),
              _FilterOptionTile(
                title: 'Lowest Per-Player Price',
                isSelected: _selectedSort == 'price_low',
                onTap: () {
                  setState(() => _selectedSort = 'price_low');
                  Navigator.pop(context);
                },
              ),
              _FilterOptionTile(
                title: 'Most Spots Left',
                isSelected: _selectedSort == 'slots',
                onTap: () {
                  setState(() => _selectedSort = 'slots');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMatchDetails(OpenMatch match) {
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
    final locationLabel = me?.location?.displayLabel ?? 'Set location';

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
                        'Open Matches',
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
                    hintText: 'Search open matches',
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
              child: StreamBuilder<List<OpenMatch>>(
                stream: _openMatchService.streamOpenMatches(),
                builder: (context, snapshot) {
                  final waitingFirst =
                      snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
                  if (waitingFirst) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final matches = _filterAndSort(
                    snapshot.data ?? const <OpenMatch>[],
                    me?.uid,
                  );
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pageHorizontal,
                        ),
                        child: Text(
                          'Open Matches Near You',
                          style: AppTextStyles.sectionTitle,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (matches.isEmpty)
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
                                    'No open matches yet',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Create one while booking a court.',
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
                        ...matches.map((m) {
                          final emoji = sportEmojiFor(m.sportType);
                          final dateText = DateFormat(
                            'EEE, MMM d',
                          ).format(m.date);
                          final whenText =
                              '$dateText · ${_formatTime(context, m.startTime)}';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: OpenMatchCard(
                              imageUrl: m.courtImageUrl,
                              title: m.courtName,
                              sport: m.sportType,
                              sportEmoji: emoji,
                              when: whenText,
                              location: m.courtAddress.isEmpty
                                  ? m.courtName
                                  : m.courtAddress,
                              joinedCount: m.joinedCount,
                              playersRequired: m.playersRequired,
                              hostName: m.hostName,
                              hostInitials: m.hostInitials,
                              hostPhotoUrl: m.hostPhotoUrl,
                              hostAvatarId: m.hostAvatarId,
                              isFull: m.isFull,
                              onJoinTap: () => _openMatchDetails(m),
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

  String _formatTime(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: h, minute: m));
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
