import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class SportsCard extends StatelessWidget {
  final String? imagePath;
  final bool isSelected;
  final bool isAllCard;
  final VoidCallback? onTap;

  const SportsCard({
    super.key,
    this.imagePath,
    this.isSelected = false,
    this.isAllCard = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isSelected ? AppColors.primary : AppColors.border;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.6),
        ),
        child: isAllCard ? const _AllSportsCardContent() : _buildImageCard(),
      ),
    );
  }

  // Sport screenshots already include the sport name,
  // so we only show the image here.
  Widget _buildImageCard() {
    return Center(
      child: Image.asset(
        imagePath!,
        fit: BoxFit.contain,
        width: 118,
        height: 118,
      ),
    );
  }
}

// "All" is the only card that still needs text because it is drawn in code.
class _AllSportsCardContent extends StatelessWidget {
  const _AllSportsCardContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(height: 18),
        _AllSportsIcon(),
        Spacer(),
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'All',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _AllSportsIcon extends StatelessWidget {
  const _AllSportsIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Center(
        child: SizedBox(
          width: 46,
          height: 46,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: List.generate(
              4,
              (_) => Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textPrimary, width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
