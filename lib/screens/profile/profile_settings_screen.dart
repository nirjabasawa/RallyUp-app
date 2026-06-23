import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/id_verification.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';
import 'edit_availability_screen.dart';
import 'edit_avatar_screen.dart';
import 'edit_sports_screen.dart';
import 'id_verification_screen.dart';
import 'id_verification_submitted_screen.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController ageController;
  late TextEditingController postalCodeController;
  late TextEditingController bioController;

  String? _firstNameError;
  String? _lastNameError;
  String? _ageError;
  String? _postalCodeError;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();

    final user = context.read<AuthProvider>().currentUser;
    firstNameController = TextEditingController(text: user?.firstName ?? '');
    lastNameController = TextEditingController(text: user?.lastName ?? '');
    ageController = TextEditingController(text: user?.age?.toString() ?? '');
    postalCodeController = TextEditingController(text: user?.postalCode ?? '');
    bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    postalCodeController.dispose();
    bioController.dispose();
    super.dispose();
  }

  String? _validateName(String value, {required bool required}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return required ? 'First name is required' : null;
    }
    if (trimmed.length < AppUser.minNameLength) {
      return 'Must be at least ${AppUser.minNameLength} characters';
    }
    if (trimmed.length > AppUser.maxNameLength) {
      return 'Must be ${AppUser.maxNameLength} characters or fewer';
    }
    return null;
  }

  String? _validateAge(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < AppUser.minAge || parsed > AppUser.maxAge) {
      return 'Enter an age between ${AppUser.minAge} and ${AppUser.maxAge}';
    }
    return null;
  }

  String? _validatePostal(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > AppUser.maxPostalCodeLength) {
      return 'Postal code is too long';
    }
    return null;
  }

  Future<void> _save() async {
    final firstNameValid = _validateName(
      firstNameController.text,
      required: true,
    );
    final lastNameValid = _validateName(
      lastNameController.text,
      required: false,
    );
    final ageValid = _validateAge(ageController.text);
    final postalValid = _validatePostal(postalCodeController.text);

    setState(() {
      _firstNameError = firstNameValid;
      _lastNameError = lastNameValid;
      _ageError = ageValid;
      _postalCodeError = postalValid;
      _formError = null;
    });

    if (firstNameValid != null ||
        lastNameValid != null ||
        ageValid != null ||
        postalValid != null) {
      return;
    }

    setState(() => _busy = true);
    try {
      final ageText = ageController.text.trim();
      final postalText = postalCodeController.text.trim();
      final auth = context.read<AuthProvider>();
      await auth.updateProfile(
        firstName: firstNameController.text,
        lastName: lastNameController.text,
        age: ageText.isEmpty ? null : int.parse(ageText),
        postalCode: postalText.isEmpty ? null : postalText,
      );
      // Bio is a separate update so the existing `updateProfile` contract
      // (which doesn't know about bio) stays unchanged. Persist whatever
      // the user typed — `updateBio` normalises empty/whitespace to null.
      await auth.updateBio(bioController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formError = 'Could not save. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? errorText,
    String? hintText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: AppColors.textSecondary,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: AppTextStyles.body.copyWith(fontSize: 16),
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          minLines: maxLines > 1 ? maxLines : null,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFEDEDED),
            hintText: hintText,
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _navRow({
    required String title,
    required String summary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.body.copyWith(fontSize: 17)),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right, color: AppColors.primary, size: 28),
          ],
        ),
      ),
    );
  }

  String _formatTime12h(BuildContext context, String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final tod = TimeOfDay(hour: h, minute: m);
    return MaterialLocalizations.of(context).formatTimeOfDay(tod);
  }

  String _sportsSummary(List<String> sports) {
    if (sports.isEmpty) return 'No sports selected yet';
    if (sports.length <= 3) return sports.join(', ');
    return '${sports.take(3).join(', ')} +${sports.length - 3} more';
  }

  String _idVerificationSummary(IdVerification? record) {
    if (record == null) return 'Not started';
    switch (record.status) {
      case IdVerificationStatus.submitted:
        return 'Submitted — pending review';
      case IdVerificationStatus.verified:
        return 'Verified · ${record.documentType.label}';
      case IdVerificationStatus.rejected:
        return 'Needs another look — tap to resubmit';
    }
  }

  String _availabilitySummary(
    BuildContext context,
    Map<String, AvailabilitySlot> availability,
  ) {
    if (availability.isEmpty) return 'No availability set';
    const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final orderedDays = order
        .where(availability.containsKey)
        .toList(growable: false);
    if (orderedDays.length > 3) {
      return '${orderedDays.take(3).join(', ')} +${orderedDays.length - 3} more';
    }
    return orderedDays
        .map((day) {
          final slot = availability[day]!;
          return '$day ${_formatTime12h(context, slot.start)}–${_formatTime12h(context, slot.end)}';
        })
        .join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initials = user?.initials ?? 'UP';
    final avatarId = user?.avatarId;
    final sports = user?.sports ?? const <String>[];
    final availability =
        user?.availability ?? const <String, AvailabilitySlot>{};

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 26,
            right: 26,
            bottom: MediaQuery.of(context).viewInsets.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.chevron_left,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 52),
                  Text('Profile Settings', style: AppTextStyles.pageTitle),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  // Opaque so the gesture is hit-testable regardless of
                  // which internal render path UserAvatar takes (photo /
                  // preset / initials). Without this, taps land on the
                  // CachedNetworkImage layer when a photo is set and never
                  // reach this handler.
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditAvatarScreen(),
                      ),
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      UserAvatar(
                        size: 100,
                        initials: initials,
                        avatarId: avatarId,
                        photoUrl: user?.photoUrl,
                      ),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.darkGreen,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditAvatarScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Change profile photo',
                    style: TextStyle(
                      color: AppColors.darkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildField(
                label: 'First Name',
                controller: firstNameController,
                errorText: _firstNameError,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppUser.maxNameLength),
                ],
              ),
              const SizedBox(height: 18),
              _buildField(
                label: 'Last Name',
                controller: lastNameController,
                errorText: _lastNameError,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppUser.maxNameLength),
                ],
              ),
              const SizedBox(height: 18),
              _buildField(
                label: 'Age',
                controller: ageController,
                errorText: _ageError,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
              ),
              const SizedBox(height: 18),
              _buildField(
                label: 'Postal Code',
                controller: postalCodeController,
                errorText: _postalCodeError,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppUser.maxPostalCodeLength),
                ],
              ),
              const SizedBox(height: 18),
              _buildField(
                label: 'About',
                controller: bioController,
                hintText: 'Tell other players a bit about yourself…',
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(AppUser.maxBioLength),
                ],
              ),
              if (_formError != null) ...[
                const SizedBox(height: 16),
                Text(
                  _formError!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              Center(
                child: PrimaryButton(
                  text: _busy ? 'Saving…' : 'Save',
                  width: 180,
                  height: 50,
                  backgroundColor: AppColors.darkGreen,
                  onPressed: _busy ? () {} : _save,
                ),
              ),
              const SizedBox(height: 24),
              _navRow(
                title: 'Sports',
                summary: _sportsSummary(sports),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditSportsScreen()),
                  );
                },
              ),
              const Divider(height: 1, color: Color(0xFFE3E6EA)),
              _navRow(
                title: 'ID Verification',
                summary: _idVerificationSummary(user?.idVerification),
                onTap: () async {
                  final hasSubmission = user?.idVerification != null;
                  if (!hasSubmission) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IdVerificationScreen(),
                      ),
                    );
                    return;
                  }
                  // Open the submitted-status view. If the user taps
                  // "Resubmit" there (only available on rejected status)
                  // it pops with `'resubmit'`; route them straight into
                  // a fresh submission flow.
                  final result = await Navigator.push<String?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const IdVerificationSubmittedScreen(),
                    ),
                  );
                  if (!context.mounted) return;
                  if (result == 'resubmit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IdVerificationScreen(),
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1, color: Color(0xFFE3E6EA)),
              _navRow(
                title: 'Availability',
                summary: _availabilitySummary(context, availability),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EditAvailabilityScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
