import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

const Map<String, List<Color>> kAvatarGradients = {
  'avatar_1': [Color(0xFF3B38F5), Color(0xFF39B54A)],
  'avatar_2': [Color(0xFFFF7A45), Color(0xFFE53935)],
  'avatar_3': [Color(0xFF8E2DE2), Color(0xFFEC4899)],
  'avatar_4': [Color(0xFF008C73), Color(0xFF59C42A)],
  'avatar_5': [Color(0xFF2196F3), Color(0xFF26C6DA)],
  'avatar_6': [Color(0xFFEC4899), Color(0xFFFFB300)],
};

/// Bundle paths for the curated avatar set. Missing files fall back
/// to the gradient + initials in the widget's `errorBuilder`.
const Map<String, String> kAvatarAssets = {
  'avatar_1': 'assets/images/avatars/avatar_1.png',
  'avatar_2': 'assets/images/avatars/avatar_2.png',
  'avatar_3': 'assets/images/avatars/avatar_3.png',
  'avatar_4': 'assets/images/avatars/avatar_4.png',
  'avatar_5': 'assets/images/avatars/avatar_5.png',
  'avatar_6': 'assets/images/avatars/avatar_6.png',
};

const List<String> kAvatarOptions = [
  'avatar_1',
  'avatar_2',
  'avatar_3',
  'avatar_4',
  'avatar_5',
  'avatar_6',
];

const List<Color> _defaultGradient = [Color(0xFF3B38F5), Color(0xFF39B54A)];

List<Color> avatarGradientFor(String? avatarId) {
  if (avatarId == null) return _defaultGradient;
  return kAvatarGradients[avatarId] ?? _defaultGradient;
}

String? avatarAssetFor(String? avatarId) {
  if (avatarId == null) return null;
  return kAvatarAssets[avatarId];
}

/// Priority chain: `photoUrl` (Cloudinary) → `avatarId` (preset) →
/// initials. Network / asset failures fall through to the next tier
/// so we never render a broken-image placeholder.
class UserAvatar extends StatelessWidget {
  final double size;
  final String initials;
  final String? photoUrl;
  final String? avatarId;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    required this.size,
    required this.initials,
    this.photoUrl,
    this.avatarId,
    this.onTap,
  });

  bool get _hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  Widget _initialsCircle() {
    final colors = avatarGradientFor(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.surface,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _build() {
    if (_hasPhoto) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: photoUrl!,
            fit: BoxFit.cover,
            placeholder: (_, _) => _initialsCircle(),
            errorWidget: (_, _, _) => _initialsCircle(),
          ),
        ),
      );
    }

    final assetPath = avatarAssetFor(avatarId);
    if (assetPath != null) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            assetPath,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _initialsCircle(),
          ),
        ),
      );
    }

    return _initialsCircle();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _build();
    if (onTap == null) return avatar;
    // `HitTestBehavior.opaque` so the tap hits at the GestureDetector
    // bounds regardless of which subtree (CachedNetworkImage / asset /
    // gradient container) is currently rendering inside.
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.square(dimension: size, child: avatar),
    );
  }
}
