import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/image_upload_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/user_avatar.dart';

class EditAvatarScreen extends StatefulWidget {
  const EditAvatarScreen({super.key});

  @override
  State<EditAvatarScreen> createState() => _EditAvatarScreenState();
}

class _EditAvatarScreenState extends State<EditAvatarScreen> {
  final ImagePicker _picker = ImagePicker();
  final ImageUploadService _uploadService = ImageUploadService();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _uploadService.dispose();
    super.dispose();
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (_busy) return;
    // Capture the provider reference up-front; using `context.read` after
    // the picker's async gap would trip the use_build_context_synchronously
    // lint and risks pointing at a defunct context.
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'You need to be signed in.');
      return;
    }
    setState(() => _error = null);

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _readablePickerError(e));
      return;
    }

    if (picked == null) return; // user cancelled

    setState(() => _busy = true);
    try {
      final url = await _uploadService.uploadProfilePhoto(
        File(picked.path),
        uid: uid,
      );
      await auth.setProfilePhotoUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
    } on ImageUploadException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not upload the photo. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _readablePickerError(Object e) {
    final msg = e.toString();
    if (msg.contains('camera_access_denied') ||
        msg.contains('photo_access_denied')) {
      return 'Permission denied. Enable camera / photos in Settings.';
    }
    return 'Could not open the picker.';
  }

  Future<void> _pickPreset(String avatarId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().updateAvatar(avatarId);
      if (!mounted) return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not save your selection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetToInitials() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.clearProfileImage();
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Switched to initials avatar')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reset your avatar.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final initials = user?.initials ?? 'U';
    final selectedAvatarId = user?.avatarId;
    final photoUrl = user?.photoUrl;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    'Profile Photo',
                    style: AppTextStyles.pageTitle.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Center(
                child: UserAvatar(
                  size: 120,
                  initials: initials,
                  avatarId: selectedAvatarId,
                  photoUrl: photoUrl,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.photo_camera_rounded,
                      label: 'Take photo',
                      onTap: _busy
                          ? null
                          : () => _pickFromSource(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.photo_library_rounded,
                      label: 'From library',
                      onTap: _busy
                          ? null
                          : () => _pickFromSource(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'Or pick a preset avatar',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _PresetGrid(
                options: kAvatarOptions,
                selectedAvatarId: selectedAvatarId,
                hasPhoto: photoUrl != null && photoUrl.isNotEmpty,
                initials: initials,
                onSelect: _busy ? null : _pickPreset,
              ),
              // The reset action is only useful when there's actually
              // something to clear. When both photoUrl and avatarId are
              // already null, the avatar is already showing initials, so
              // hiding the button prevents the "is it broken?" confusion.
              if (photoUrl != null && photoUrl.isNotEmpty ||
                  selectedAvatarId != null) ...[
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _busy ? null : _resetToInitials,
                    child: const Text(
                      'Reset to initials',
                      style: TextStyle(
                        color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(color: AppColors.darkGreen),
                ),
              ],
              const SizedBox(height: 28),
              Center(
                child: PrimaryButton(
                  text: 'Done',
                  width: 180,
                  height: 48,
                  backgroundColor: AppColors.darkGreen,
                  onPressed: _busy ? () {} : () => Navigator.pop(context),
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: AppColors.lightGray,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(
                icon,
                color: disabled ? AppColors.grayText : AppColors.darkGreen,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: disabled ? AppColors.grayText : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetGrid extends StatelessWidget {
  final List<String> options;
  final String? selectedAvatarId;
  final bool hasPhoto;
  final String initials;
  final ValueChanged<String>? onSelect;

  const _PresetGrid({
    required this.options,
    required this.selectedAvatarId,
    required this.hasPhoto,
    required this.initials,
    required this.onSelect,
  });

  Widget _buildOption(BuildContext context, String id) {
    // A preset is "active" only when there's no uploaded photo overriding
    // it. With a photo present, we still let the user tap to switch, which
    // clears the photo via AuthProvider.updateAvatar.
    final isSelected = !hasPhoto && selectedAvatarId == id;
    return GestureDetector(
      onTap: onSelect == null ? null : () => onSelect!(id),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppColors.darkGreen : Colors.transparent,
            width: 3,
          ),
        ),
        child: UserAvatar(size: 60, initials: initials, avatarId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 3) {
      final chunk = options.skip(i).take(3).toList();
      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: chunk.map((id) => _buildOption(context, id)).toList(),
        ),
      );
      if (i + 3 < options.length) {
        rows.add(const SizedBox(height: 14));
      }
    }
    return Column(children: rows);
  }
}
