import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class CourtSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final String hintText;

  const CourtSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onFilterTap,
    this.hintText = 'Search courts, venues or sports',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onFilterTap,
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(
              Icons.tune_rounded,
              size: 30,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
