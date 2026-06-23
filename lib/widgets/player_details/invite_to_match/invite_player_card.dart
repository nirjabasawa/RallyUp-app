import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../user_avatar.dart';
import 'invite_to_match_surface.dart';

class InvitePlayerCard extends StatelessWidget {
  final AppUser user;

  const InvitePlayerCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final primarySport = user.sports.isNotEmpty
        ? user.sports.first
        : 'Multi-sport';
    final locationLabel = user.location?.displayLabel;

    return InviteToMatchSurface(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          UserAvatar(
            size: 52,
            initials: user.initials,
            photoUrl: user.photoUrl,
            avatarId: user.avatarId,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      primarySport,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (locationLabel != null && locationLabel.isNotEmpty) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          '📍 $locationLabel',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
