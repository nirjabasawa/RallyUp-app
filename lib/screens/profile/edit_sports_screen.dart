import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';

class EditSportsScreen extends StatefulWidget {
  const EditSportsScreen({super.key});

  @override
  State<EditSportsScreen> createState() => _EditSportsScreenState();
}

class _EditSportsScreenState extends State<EditSportsScreen> {
  static const List<Map<String, String>> _sports = [
    {'name': 'Tennis', 'image': 'assets/images/login/tennis.png'},
    {'name': 'Swimming', 'image': 'assets/images/login/swimming.png'},
    {'name': 'Badminton', 'image': 'assets/images/login/badminton.png'},
    {'name': 'Soccer', 'image': 'assets/images/login/soccer.png'},
    {'name': 'Table Tennis', 'image': 'assets/images/login/tabletennis.png'},
    {'name': 'Basketball', 'image': 'assets/images/login/basketball.png'},
    {'name': 'Volleyball', 'image': 'assets/images/login/volleyball.png'},
    {'name': 'Pickleball', 'image': 'assets/images/login/pickleball.png'},
    {'name': 'Cricket', 'image': 'assets/images/login/cricket.png'},
    {'name': 'Football', 'image': 'assets/images/login/football.png'},
  ];

  late Set<String> _selected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current =
        context.read<AuthProvider>().currentUser?.sports ?? const [];
    _selected = current.toSet();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateSports(_selected.toList());
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save sports. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.chevron_left,
                      color: AppColors.darkGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'My Sports',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Pick the sports you play.',
                style: AppTextStyles.body.copyWith(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _sports.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 22,
                    crossAxisSpacing: 22,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final sport = _sports[index];
                    final name = sport['name']!;
                    final image = sport['image']!;
                    final isSelected = _selected.contains(name);

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(name);
                          } else {
                            _selected.add(name);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.darkGreen
                                : Colors.transparent,
                            width: 3,
                          ),
                          image: DecorationImage(
                            image: AssetImage(image),
                            fit: BoxFit.cover,
                            colorFilter: ColorFilter.mode(
                              Colors.black.withValues(alpha: .25),
                              BlendMode.darken,
                            ),
                          ),
                        ),
                        alignment: Alignment.bottomCenter,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: PrimaryButton(
        text: _busy ? 'Saving…' : 'Save',
        width: 180,
        height: 50,
        backgroundColor: AppColors.darkGreen,
        onPressed: _busy ? () {} : _save,
      ),
    );
  }
}
