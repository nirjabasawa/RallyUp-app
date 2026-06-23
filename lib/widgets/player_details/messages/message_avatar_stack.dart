import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class MessageAvatarData {
  final String initials;
  final Color backgroundColor;
  final String? imagePath;

  const MessageAvatarData({
    required this.initials,
    required this.backgroundColor,
    this.imagePath,
  });
}

class MessageAvatarStack extends StatelessWidget {
  final List<MessageAvatarData> avatars;
  final bool online;

  const MessageAvatarStack({
    super.key,
    required this.avatars,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    if (avatars.length <= 1) {
      return _MessageAvatar(data: avatars.first, size: 54, online: online);
    }

    return SizedBox(
      width: 58,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 8,
            child: _MessageAvatar(data: avatars[1], size: 36),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: _MessageAvatar(data: avatars.first, size: 44),
          ),
        ],
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  final MessageAvatarData data;
  final double size;
  final bool online;

  const _MessageAvatar({
    required this.data,
    required this.size,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: data.backgroundColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.surface, width: 2),
          ),
          child: ClipOval(
            child: data.imagePath == null
                ? Center(
                    child: Text(
                      data.initials,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                : Image.asset(data.imagePath!, fit: BoxFit.cover),
          ),
        ),
        if (online)
          Positioned(
            right: 1,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: AppColors.brightGreen,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
