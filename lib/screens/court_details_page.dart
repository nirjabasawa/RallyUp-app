import 'package:flutter/material.dart';

import '../models/court.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import '../utils/sport_emoji.dart';
import '../widgets/court_details/book_court_sheet.dart';
import '../widgets/court_details/court_image_carousel.dart';
import '../widgets/main_bottom_nav.dart';
import '../widgets/notification_bell_button.dart';
import 'main_shell_nav.dart';

/// Court details. Takes a real [Court] plus the caller's
/// pre-computed distance label so we don't redo haversine.
class CourtDetailsPage extends StatefulWidget {
  final Court court;
  final String distanceText;

  const CourtDetailsPage({
    super.key,
    required this.court,
    required this.distanceText,
  });

  @override
  State<CourtDetailsPage> createState() => _CourtDetailsPageState();
}

class _CourtDetailsPageState extends State<CourtDetailsPage> {
  late String _selectedSport = widget.court.sportTypes.isNotEmpty
      ? widget.court.sportTypes.first
      : 'Tennis';

  void _openBookCourtSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BookCourtSheet(
          court: widget.court,
          initialSport: _selectedSport,
        );
      },
    );
  }

  void _onBottomNavTap(BuildContext context, int index) {
    switchToMainShellTab(context, index);
  }

  /// "🎾  Tennis · Badminton · Pickleball". Single-sport courts
  /// collapse to just `{emoji}  {name}`.
  String _topSportLabel(List<String> sportTypes, String selectedEmoji) {
    if (sportTypes.length <= 1) {
      return '$selectedEmoji  $_selectedSport';
    }
    final others = sportTypes
        .where((s) => s.toLowerCase() != _selectedSport.toLowerCase())
        .toList();
    if (others.isEmpty) return '$selectedEmoji  $_selectedSport';
    return '$selectedEmoji  $_selectedSport · ${others.join(' · ')}';
  }

  IconData _iconForAmenity(String label) {
    final l = label.toLowerCase();
    if (l.contains('parking')) return Icons.local_parking_outlined;
    if (l.contains('light')) return Icons.light_mode_outlined;
    if (l.contains('restroom')) return Icons.wc_outlined;
    if (l.contains('water')) return Icons.water_drop_outlined;
    if (l.contains('seat')) return Icons.event_seat_outlined;
    if (l.contains('rental') || l.contains('equipment')) {
      return Icons.sports_tennis_outlined;
    }
    if (l.contains('indoor')) return Icons.home_work_outlined;
    if (l.contains('outdoor') || l.contains('field') || l.contains('ground')) {
      return Icons.park_outlined;
    }
    if (l.contains('net')) return Icons.sports_baseball_outlined;
    if (l.contains('multi')) return Icons.dashboard_customize_outlined;
    if (l.contains('community')) return Icons.groups_outlined;
    return Icons.check_circle_outline_rounded;
  }

  Widget _buildAmenityItem(String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_iconForAmenity(label), size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final court = widget.court;
    final emoji = sportEmojiFor(_selectedSport);
    final ratingText = court.rating == null
        ? '—'
        : court.rating!.toStringAsFixed(1);
    final priceText = '\$${court.pricePerHour.toStringAsFixed(0)}/hr';
    final locationText = court.city.isEmpty
        ? court.address
        : '${court.city}, ${court.region}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                18,
                AppSpacing.pageHorizontal,
                10,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Court Details',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const NotificationBellButton(size: 30),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Image carousel — swipeable when multiple images,
                  // single fixed image when only one, placeholder
                  // when none. Keeps the same 210px image area the
                  // page had with a single Image.asset before.
                  CourtImageCarousel(imageUrls: court.imageUrls, height: 210),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pageHorizontal,
                      18,
                      AppSpacing.pageHorizontal,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          court.name,
                          style: AppTextStyles.pageTitle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Multi-sport venues must read clearly as
                            // multi-sport here. Lead with the
                            // currently-selected sport's emoji + name
                            // (this is the one Book Court will use),
                            // then a small grey tail of the remaining
                            // sports so a Cupertino card reads
                            // "🎾 Tennis · Badminton · Pickleball"
                            // rather than just "🎾 Tennis".
                            Flexible(
                              child: Text(
                                _topSportLabel(court.sportTypes, emoji),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF4B400),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              ratingText,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              widget.distanceText,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              '•',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                locationText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          priceText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'About this venue',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          court.description.isNotEmpty
                              ? court.description
                              : 'No description provided yet.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Amenities',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (court.amenities.isEmpty)
                          Text(
                            'No listed amenities.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 18,
                            runSpacing: 10,
                            children: [
                              for (final a in court.amenities)
                                _buildAmenityItem(a),
                            ],
                          ),
                        const SizedBox(height: 18),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 14),
                        Text(
                          'Available for',
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in court.sportTypes)
                              _buildSelectableChip(
                                label: s,
                                isSelected: _selectedSport == s,
                                onTap: () => setState(() => _selectedSport = s),
                              ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: () => _openBookCourtSheet(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Book Now',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNav(
        currentIndex: null,
        onTap: (index) => _onBottomNavTap(context, index),
      ),
    );
  }
}
