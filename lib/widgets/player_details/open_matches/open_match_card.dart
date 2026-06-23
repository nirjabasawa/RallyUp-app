import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../courts/court_network_image.dart';
import '../../user_avatar.dart';

/// Open match list card. Now driven entirely by real Firestore data
/// passed in by the page — the previous static-mock parameters
/// (asset path, free-form players "3 / 4", spotLabel) were replaced
/// with the underlying numeric/string fields so the card can compute
/// labels and disabled state consistently.
class OpenMatchCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String sport;
  final String sportEmoji;
  final String when;
  final String location;
  final int joinedCount;
  final int playersRequired;
  final String hostName;
  final String hostInitials;
  final String? hostPhotoUrl;
  final String? hostAvatarId;
  final bool isFull;
  final VoidCallback? onJoinTap;

  const OpenMatchCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.sport,
    required this.sportEmoji,
    required this.when,
    required this.location,
    required this.joinedCount,
    required this.playersRequired,
    required this.hostName,
    required this.hostInitials,
    this.hostPhotoUrl,
    this.hostAvatarId,
    required this.isFull,
    this.onJoinTap,
  });

  int get _spotsLeft {
    final v = playersRequired - joinedCount;
    return v < 0 ? 0 : v;
  }

  String get _spotLabel {
    if (isFull) return 'Match Full';
    final n = _spotsLeft;
    if (n == 1) return '1 spot left';
    return '$n spots left';
  }

  Color get _spotColor {
    if (isFull) return AppColors.muted;
    if (_spotsLeft == 1) return AppColors.primary;
    if (_spotsLeft == 2) return const Color(0xFFD97706);
    if (_spotsLeft == 3) return AppColors.warning;
    return AppColors.primary;
  }

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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 210,
                  child: CourtNetworkImage(
                    url: imageUrl.isEmpty ? null : imageUrl,
                    iconSize: 38,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _spotColor.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _spotLabel,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
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
                        '$sportEmoji  $sport • $when',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
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
                    Expanded(
                      child: Text(
                        location,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_2_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '$joinedCount / $playersRequired players',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    UserAvatar(
                      size: 28,
                      initials: hostInitials,
                      photoUrl: hostPhotoUrl,
                      avatarId: hostAvatarId,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hosted by $hostName',
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 132,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onJoinTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.4,
                          ),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              isFull ? 'Match Full' : 'View Match',
                              maxLines: 1,
                              softWrap: false,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
