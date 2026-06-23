import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

class InvitesHeader extends StatelessWidget {
  final VoidCallback? onBackTap;

  const InvitesHeader({super.key, this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBackTap ?? () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: AppColors.textPrimary,
              tooltip: 'Back',
            ),
          ),
          Text(
            'Invites',
            textAlign: TextAlign.center,
            style: AppTextStyles.pageTitle.copyWith(
              fontSize: 22,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}
