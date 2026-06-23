import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'availability_day_chip.dart';
import 'daywise_timing_row.dart';

class AvailabilitySection extends StatelessWidget {
  const AvailabilitySection({super.key});

  static const List<String> _days = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  static const List<(String, String)> _timings = [
    ('Sunday', '9:00 PM - 11:54 PM'),
    ('Monday', '9:00 PM - 11:55 PM'),
    ('Tuesday', '9:00 PM - 11:55 PM'),
    ('Wednesday', '9:00 PM - 11:55 PM'),
    ('Thursday', '9:00 PM - 11:55 PM'),
    ('Friday', '9:00 PM - 11:55 PM'),
    ('Saturday', '9:00 PM - 11:55 PM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Availability',
            style: AppTextStyles.bodyMedium.copyWith(
              color: const Color(0xFF1E3A8A),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Days', style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final day in _days) AvailabilityDayChip(label: day),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Daywise Timings',
            style: AppTextStyles.sectionTitle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final timing in _timings) ...[
            DaywiseTimingRow(day: timing.$1, time: timing.$2),
            if (timing != _timings.last)
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
          ],
        ],
      ),
    );
  }
}
