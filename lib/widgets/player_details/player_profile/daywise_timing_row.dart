import 'package:flutter/material.dart';

import '../../../theme/app_text_styles.dart';

class DaywiseTimingRow extends StatelessWidget {
  final String day;
  final String time;

  const DaywiseTimingRow({super.key, required this.day, required this.time});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 49,
      child: Row(
        children: [
          Expanded(
            child: Text(
              day,
              style: AppTextStyles.body.copyWith(
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
          Text(
            time,
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
