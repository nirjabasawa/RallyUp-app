import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'notification_bell_button.dart';

class RallyHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final bool showMenuButton;
  final bool showNotificationButton;
  final VoidCallback? onBackTap;
  final VoidCallback? onMenuTap;

  const RallyHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.showMenuButton = false,
    this.showNotificationButton = true,
    this.onBackTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          _buildLeading(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(title, style: AppTextStyles.pageTitle)),
          if (showNotificationButton)
            // The bell carries its own tap target + unread-dot stream,
            // wrapped to roughly match the 48dp IconButton hit slop
            // we used to have so spacing on every RallyHeader page
            // stays consistent.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: NotificationBellButton(size: 24),
            ),
        ],
      ),
    );
  }

  Widget _buildLeading() {
    if (showBackButton) {
      return IconButton(
        onPressed: onBackTap,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textPrimary,
          size: 22,
        ),
        splashRadius: 22,
        tooltip: 'Back',
      );
    }

    if (showMenuButton) {
      return IconButton(
        onPressed: onMenuTap,
        icon: const Icon(
          Icons.menu_rounded,
          color: AppColors.textPrimary,
          size: 26,
        ),
        splashRadius: 22,
        tooltip: 'Menu',
      );
    }

    // Keeping a placeholder space here helps all page titles stay aligned
    // even when a page does not show a back or menu button.
    return const SizedBox(width: 48);
  }
}
