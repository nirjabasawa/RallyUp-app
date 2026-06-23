import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Top bar used on every Messages-tab variant.
///
/// Right-side action:
///   * Callers that need a real right-side widget (e.g. the primary
///     Messages tab wants a NotificationBellButton) pass [trailing].
///     That widget is rendered as-is inside the same 52×52 slot the
///     compose icon used to occupy, keeping the header rhythm
///     identical.
///   * Callers that want the legacy compose icon pass
///     [onComposeTap]; the pencil button only renders when a tap
///     callback is actually wired.
///   * If both are null (Unread / Group variants today) we render an
///     empty 52×52 spacer so the title/back alignment stays balanced
///     without a misleading nonfunctional pencil control.
class MessagesHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final bool showMenuButton;
  final VoidCallback? onMenuTap;
  final VoidCallback? onComposeTap;
  final Widget? trailing;

  const MessagesHeader({
    super.key,
    this.title = 'Messages',
    this.showBackButton = false,
    this.showMenuButton = false,
    this.onMenuTap,
    this.onComposeTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        18,
        AppSpacing.pageHorizontal,
        8,
      ),
      child: Row(
        children: [
          if (showBackButton)
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 30,
                color: AppColors.textPrimary,
              ),
            )
          else if (showMenuButton)
            IconButton(
              onPressed: onMenuTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(
                Icons.menu_rounded,
                size: 34,
                color: AppColors.textPrimary,
              ),
            )
          else
            const SizedBox(width: 34),
          const SizedBox(width: 18),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.pageTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null)
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: trailing,
            )
          else if (onComposeTap != null)
            GestureDetector(
              onTap: onComposeTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            )
          else
            const SizedBox(width: 52, height: 52),
        ],
      ),
    );
  }
}
