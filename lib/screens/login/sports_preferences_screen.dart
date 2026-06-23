import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/signup_form_provider.dart';
import '../../services/location_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/primary_button.dart';

class SportsPreferencesScreen extends StatefulWidget {
  const SportsPreferencesScreen({super.key});

  @override
  State<SportsPreferencesScreen> createState() =>
      _SportsPreferencesScreenState();
}

class _SportsPreferencesScreenState extends State<SportsPreferencesScreen> {
  final List<Map<String, String>> sports = const [
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

  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  String _query = '';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> get _filteredSports {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return sports;
    return sports
        .where((s) => s['name']!.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> finishOnboarding() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final form = context.read<SignupFormProvider>();
      // Capture the AuthProvider reference up-front: we have one async hop
      // for GPS capture before we use it, and grabbing it now avoids a
      // BuildContext-across-async-gaps lint.
      final auth = context.read<AuthProvider>();
      // Best-effort GPS capture if the user never picked a location during
      // onboarding. Hard 8-second cap so a hung permission dialog, an offline
      // emulator, or a slow reverse-geocode can never block the "Done" button
      // — any failure falls through and the user is created without a
      // location, which the rest of the app handles gracefully.
      if (form.location == null) {
        try {
          final captured = await _locationService.captureCurrent().timeout(
            const Duration(seconds: 8),
          );
          form.setLocation(captured);
        } catch (_) {
          // permission denied / service off / timeout / geocoding failed —
          // skip silently. Profile settings has a manual picker the user can
          // use later.
        }
      }
      await auth.completeOnboarding(form.data);
      if (!mounted) return;
      // AuthGate now reports authenticated → showing MainShell at the root.
      // Pop everything pushed on top of the gate so MainShell becomes visible.
      Navigator.of(context).popUntil((route) => route.isFirst);
      // Clear the in-memory form after a successful submit.
      form.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not save your profile. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = context.watch<SignupFormProvider>();
    final selected = form.selectedSports;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
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

              const SizedBox(height: 18),

              const Text(
                'Pick your favorites!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.darkGray,
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: "Type 'Cycling'",
                  hintStyle: const TextStyle(color: AppColors.grayText),
                  filled: true,
                  fillColor: AppColors.lightGray,
                  suffixIcon: _query.isEmpty
                      ? const Icon(Icons.search, color: AppColors.grayText)
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.grayText,
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                const SizedBox(height: 8),
              ],

              Expanded(
                child: _filteredSports.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 80),
                          child: Text(
                            'No sports match "${_query.trim()}"',
                            style: const TextStyle(
                              color: AppColors.grayText,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _filteredSports.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 22,
                              crossAxisSpacing: 22,
                              childAspectRatio: 1.05,
                            ),
                        itemBuilder: (context, index) {
                          final sport = _filteredSports[index];
                          final name = sport['name']!;
                          final image = sport['image']!;
                          final isSelected = selected.contains(name);

                          return GestureDetector(
                            onTap: () {
                              context.read<SignupFormProvider>().toggleSport(
                                name,
                              );
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
        text: _busy ? 'Saving…' : 'Done',
        width: 180,
        height: 50,
        backgroundColor: AppColors.darkGreen,
        onPressed: _busy ? () {} : finishOnboarding,
      ),
    );
  }
}
