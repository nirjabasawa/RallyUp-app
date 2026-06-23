import 'package:flutter/material.dart';

import '../../../widgets/sports_card.dart';
import '../../../theme/app_spacing.dart';

class OpenMatchesSportsSelector extends StatelessWidget {
  final String selectedSport;
  final ValueChanged<String>? onSportSelected;

  const OpenMatchesSportsSelector({
    super.key,
    this.selectedSport = 'All',
    this.onSportSelected,
  });

  static const List<_OpenMatchesSport> _sports = [
    _OpenMatchesSport('All'),
    _OpenMatchesSport('Tennis', 'assets/images/sports/tennis.png'),
    _OpenMatchesSport('Badminton', 'assets/images/sports/badminton.png'),
    _OpenMatchesSport('Table Tennis', 'assets/images/sports/table_tennis.png'),
    _OpenMatchesSport('Basketball', 'assets/images/sports/basketball.png'),
    _OpenMatchesSport('Volleyball', 'assets/images/sports/volleyball.png'),
    _OpenMatchesSport('Pickleball', 'assets/images/sports/pickleball.png'),
    _OpenMatchesSport('Soccer', 'assets/images/sports/soccer.png'),
    _OpenMatchesSport('Football', 'assets/images/sports/football.png'),
    _OpenMatchesSport('Cricket', 'assets/images/sports/cricket.png'),
    _OpenMatchesSport('Swimming', 'assets/images/sports/swimming.png'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          for (final sport in _sports) ...[
            SizedBox(
              width: 118,
              height: 170,
              child: SportsCard(
                imagePath: sport.imagePath,
                isAllCard: sport.label == 'All',
                isSelected: selectedSport == sport.label,
                onTap: () => onSportSelected?.call(sport.label),
              ),
            ),
            if (sport != _sports.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _OpenMatchesSport {
  final String label;
  final String? imagePath;

  const _OpenMatchesSport(this.label, [this.imagePath]);
}
