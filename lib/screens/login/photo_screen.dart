import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/signup_form_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';
import 'sports_preferences_screen.dart';

class PhotoScreen extends StatelessWidget {
  const PhotoScreen({super.key});

  static const List<String> _avatarOptions = [
    'avatar_1',
    'avatar_2',
    'avatar_3',
    'avatar_4',
    'avatar_5',
    'avatar_6',
  ];

  String _computeInitials(String first, String last) {
    final f = first.trim();
    final l = last.trim();
    if (f.isEmpty && l.isEmpty) return 'U';
    if (l.isEmpty) return f[0].toUpperCase();
    return '${f[0]}${l[0]}'.toUpperCase();
  }

  void _goToSports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SportsPreferencesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<SignupFormProvider>();
    final initials = _computeInitials(form.firstName, form.lastName);
    final selectedAvatarId = form.avatarId;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 54),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(
                  Icons.chevron_left,
                  color: AppColors.darkGreen,
                  size: 28,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Pick your avatar',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGray,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Tap one to use as your profile avatar, or skip to use your initials.",
                style: TextStyle(fontSize: 13, color: AppColors.grayText),
              ),

              const SizedBox(height: 28),

              Center(
                child: UserAvatar(
                  size: 110,
                  initials: initials,
                  avatarId: selectedAvatarId,
                ),
              ),

              const SizedBox(height: 28),

              _AvatarPickerGrid(
                options: _avatarOptions,
                selectedAvatarId: selectedAvatarId,
                initials: initials,
                onSelect: (id) {
                  final isSelected = selectedAvatarId == id;
                  context.read<SignupFormProvider>().setAvatarId(
                    isSelected ? null : id,
                  );
                },
              ),

              const SizedBox(height: 20),

              Center(
                child: TextButton(
                  onPressed: () {
                    context.read<SignupFormProvider>().setAvatarId(null);
                  },
                  child: const Text(
                    'Use initials only',
                    style: TextStyle(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Center(
                child: PrimaryButton(
                  text: 'Continue',
                  width: 180,
                  height: 48,
                  backgroundColor: AppColors.darkGreen.withValues(alpha: 0.75),
                  onPressed: () => _goToSports(context),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPickerGrid extends StatelessWidget {
  final List<String> options;
  final String? selectedAvatarId;
  final String initials;
  final ValueChanged<String> onSelect;

  const _AvatarPickerGrid({
    required this.options,
    required this.selectedAvatarId,
    required this.initials,
    required this.onSelect,
  });

  Widget _buildOption(String id) {
    final isSelected = selectedAvatarId == id;
    return GestureDetector(
      onTap: () => onSelect(id),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.darkGreen : Colors.transparent,
            width: 3,
          ),
        ),
        child: UserAvatar(size: 64, initials: initials, avatarId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Force a clean 3-per-row layout regardless of available width.
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 3) {
      final chunk = options.skip(i).take(3).toList();
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: chunk.map(_buildOption).toList(),
        ),
      );
      if (i + 3 < options.length) {
        rows.add(const SizedBox(height: 18));
      }
    }
    return Column(children: rows);
  }
}
