import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

class PlayerProfileActionButtons extends StatelessWidget {
  final VoidCallback? onConnectTap;
  final VoidCallback? onInviteTap;

  const PlayerProfileActionButtons({
    super.key,
    this.onConnectTap,
    this.onInviteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Row(
            children: [
              Expanded(
                child: _PlayerProfileActionButton(
                  label: 'Connect',
                  icon: Icons.person_add_alt_1_rounded,
                  filled: true,
                  onTap: onConnectTap,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _PlayerProfileActionButton(
                  label: 'Invite',
                  icon: Icons.near_me_outlined,
                  filled: false,
                  onTap: onInviteTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerProfileActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onTap;

  const _PlayerProfileActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color foreground = filled ? AppColors.white : AppColors.brightGreen;

    return Material(
      color: filled ? AppColors.primary : AppColors.primaryLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled ? null : Border.all(color: AppColors.brightGreen),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
