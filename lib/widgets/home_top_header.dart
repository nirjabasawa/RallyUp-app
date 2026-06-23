import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'notification_bell_button.dart';
import 'user_avatar.dart';

class HomeTopHeader extends StatelessWidget {
  final String firstName;
  final String initials;
  final String? avatarId;
  final String? photoUrl;
  final String locationText;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLocationTap;

  const HomeTopHeader({
    super.key,
    required this.firstName,
    required this.initials,
    this.avatarId,
    this.photoUrl,
    required this.locationText,
    this.onProfileTap,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final greeting = firstName.trim().isEmpty
        ? 'Welcome 👋'
        : 'Hi ${firstName.trim()} 👋';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        14,
        AppSpacing.pageHorizontal,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 46,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF0B6B43), Color(0xFF59C42A)],
                ).createShader(bounds),
                child: Text(
                  'RallyUp',
                  style: AppTextStyles.pageTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              const Spacer(),
              const NotificationBellButton(size: 28),
              const SizedBox(width: 14),
              UserAvatar(
                size: 50,
                initials: initials,
                photoUrl: photoUrl,
                avatarId: avatarId,
                onTap: onProfileTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ready for the game?',
                      style: AppTextStyles.pageTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: GestureDetector(
                  onTap: onLocationTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        locationText,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
