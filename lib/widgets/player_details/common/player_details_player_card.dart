import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import '../../user_avatar.dart';
import 'player_details_card.dart';
import 'player_details_primary_button.dart';

/// Nearby-players list card.
///
/// Previously rendered a hardcoded skill-level chip plus a dummy
/// "Available this week · 6 PM - 8 PM" row. AppUser has no level or
/// availability-summary fields yet, so those props were fake — they
/// have been removed rather than displayed as static text on every
/// card. Rating stays for now per spec (no real data backing either,
/// but explicitly kept).
class PlayerDetailsPlayerCard extends StatelessWidget {
  final String name;
  final String initials;
  final String? photoUrl;
  final String? avatarId;
  final String sport;
  final String distance;
  final String bio;
  final String actionLabel;
  final double rating;
  final VoidCallback? onViewProfileTap;
  final VoidCallback? onActionTap;

  const PlayerDetailsPlayerCard({
    super.key,
    required this.name,
    required this.initials,
    this.photoUrl,
    this.avatarId,
    required this.sport,
    required this.distance,
    required this.bio,
    this.actionLabel = 'Connect',
    this.rating = 4.8,
    this.onViewProfileTap,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return PlayerDetailsCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(
                  size: 56,
                  initials: initials,
                  photoUrl: photoUrl,
                  avatarId: avatarId,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name, style: AppTextStyles.bodyMedium),
                          ),
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF5A623),
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _MetaText(label: sport, icon: Icons.sports_tennis),
                          _MetaText(
                            label: distance,
                            icon: Icons.location_on_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(bio, style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: PlayerDetailsPrimaryButton(
                    label: 'View Profile',
                    outlined: true,
                    onPressed: onViewProfileTap,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: PlayerDetailsPrimaryButton(
                    label: actionLabel,
                    icon: actionLabel == 'Invite'
                        ? Icons.mail_outline_rounded
                        : Icons.person_add_alt_1_rounded,
                    onPressed: onActionTap,
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

class _MetaText extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MetaText({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
