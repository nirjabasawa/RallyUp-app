import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

class AvailabilityDayChip extends StatelessWidget {
  final String label;

  const AvailabilityDayChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF34D399)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: const Color(0xFF059669),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
