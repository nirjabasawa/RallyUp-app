import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class InviteToMatchSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const InviteToMatchSurface({
    super.key,
    required this.child,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
