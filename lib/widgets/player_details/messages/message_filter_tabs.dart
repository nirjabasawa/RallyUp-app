import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

class MessageFilterTabs extends StatelessWidget {
  final String selectedFilter;
  final VoidCallback? onAllTap;
  final VoidCallback? onUnreadTap;
  final VoidCallback? onGroupsTap;

  const MessageFilterTabs({
    super.key,
    this.selectedFilter = 'All',
    this.onAllTap,
    this.onUnreadTap,
    this.onGroupsTap,
  });

  static const List<String> _tabs = ['All', 'Unread', 'Groups'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final tab in _tabs) ...[
          _MessageFilterChip(
            label: tab,
            selected: tab == selectedFilter,
            onTap: switch (tab) {
              'Unread' => onUnreadTap,
              'Groups' => onGroupsTap,
              _ => onAllTap,
            },
          ),
          if (tab != _tabs.last) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _MessageFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _MessageFilterChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(20);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: borderRadius,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
