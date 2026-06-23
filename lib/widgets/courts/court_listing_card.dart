import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'court_network_image.dart';

/// Single court tile rendered on the Courts tab. Takes already-built
/// display strings instead of a `Court` so the page can format
/// distance / price / rating consistently with its current visual
/// language and the card stays presentational only.
///
/// Image source is a Cloudinary URL (`imageUrl`). A null/empty URL or
/// a network failure falls back to a clean RallyUp-style placeholder
/// — the card never shows a broken-image icon or crashes the list.
///
/// The top-right heart/favorite icon was removed — it was a local-only
/// UI toggle with no persistence. The top-left "N slots today" badge
/// was also removed; per-slot availability still gates the booking
/// sheet via `CourtAvailabilityService`, but the card no longer
/// surfaces a count.
class CourtListingCard extends StatelessWidget {
  final String? imageUrl;
  final String title;
  final String sportsLabel;
  final String sportEmoji;
  final String distanceText;
  final String ratingText;
  final String priceText;
  final VoidCallback? onViewDetailsTap;

  const CourtListingCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.sportsLabel,
    required this.sportEmoji,
    required this.distanceText,
    required this.ratingText,
    required this.priceText,
    this.onViewDetailsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromARGB(18, 0, 0, 0),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: SizedBox(
              width: double.infinity,
              height: 210,
              child: CourtNetworkImage(url: imageUrl, iconSize: 38),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$sportEmoji  $sportsLabel',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      distanceText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
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
                    const Spacer(),
                    Text(
                      priceText,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 34,
                  child: ElevatedButton(
                    onPressed: onViewDetailsTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'View Details',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
    );
  }
}
