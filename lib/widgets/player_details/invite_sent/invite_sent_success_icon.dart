import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class InviteSentSuccessIcon extends StatelessWidget {
  const InviteSentSuccessIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brightGreen.withValues(alpha: 0.28),
                  blurRadius: 30,
                  spreadRadius: 3,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.send_rounded,
              color: AppColors.white,
              size: 44,
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
