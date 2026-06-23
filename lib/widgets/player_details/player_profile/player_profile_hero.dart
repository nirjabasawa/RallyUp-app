import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

class PlayerProfileHero extends StatelessWidget {
  final String heroImagePath;
  final String avatarImagePath;
  final VoidCallback? onBackTap;

  const PlayerProfileHero({
    super.key,
    required this.heroImagePath,
    required this.avatarImagePath,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 214,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: 176,
            width: double.infinity,
            child: Image.asset(heroImagePath, fit: BoxFit.cover),
          ),
          Positioned.fill(
            bottom: 38,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.black.withValues(alpha: 0.18),
                    AppColors.black.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.xs,
            top: AppSpacing.xl,
            child: IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
              tooltip: 'Back',
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.14),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(avatarImagePath, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
