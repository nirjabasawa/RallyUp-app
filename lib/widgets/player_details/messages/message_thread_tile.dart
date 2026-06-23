import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'message_avatar_stack.dart';
import 'message_status_badge.dart';

class MessageThreadTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String status;
  final int unreadCount;
  final bool online;
  final bool isGroup;
  final List<MessageAvatarData> avatars;
  final VoidCallback? onTap;

  const MessageThreadTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.status,
    required this.avatars,
    this.unreadCount = 0,
    this.online = false,
    this.isGroup = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUnread = unreadCount > 0;
    final borderRadius = BorderRadius.circular(AppSpacing.cardRadius);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: borderRadius,
              border: Border.all(
                color: hasUnread
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(
                    alpha: hasUnread ? 0.07 : 0.035,
                  ),
                  blurRadius: hasUnread ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                MessageAvatarStack(
                  avatars: avatars,
                  online: online && !isGroup,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            time,
                            style: AppTextStyles.caption.copyWith(
                              color: hasUnread
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: AppTextStyles.body.copyWith(
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          MessageStatusBadge(count: unreadCount),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isGroup
                                ? Icons.groups_2_outlined
                                : online
                                ? Icons.circle
                                : Icons.circle_outlined,
                            size: isGroup ? 15 : 9,
                            color: online || isGroup
                                ? AppColors.brightGreen
                                : AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            status,
                            style: AppTextStyles.caption.copyWith(
                              color: online || isGroup
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
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
