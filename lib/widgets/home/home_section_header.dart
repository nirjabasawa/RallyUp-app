import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAllTap;

  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          Text(title, style: AppTextStyles.sectionTitle),
          const Spacer(),
          GestureDetector(
            onTap: onViewAllTap,
            child: Text(
              'View All',
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
