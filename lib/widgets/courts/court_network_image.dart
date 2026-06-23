import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Shared `Image.network` for court / booking images.
///
/// Reasons it lives in its own widget:
///
///   1. Every card / carousel rendered the same loading-spinner +
///      RallyUp-tinted placeholder fallback. Pulling it into one
///      widget keeps the visual identical across CourtListingCard,
///      HomeSuggestedCourtPreviewCard, BookingPreviewCard,
///      MyBookingListCard, BookingConfirmedPage, and the
///      CourtImageCarousel.
///   2. In `kDebugMode`, the `errorBuilder` debugPrints the failing
///      URL exactly once per surface — so a broken Cloudinary cloud
///      name / public ID surfaces in the console instead of being
///      silently swallowed under a placeholder. That visibility is
///      what let us catch the "every court is a placeholder" bug.
class CourtNetworkImage extends StatefulWidget {
  final String? url;
  final BoxFit fit;
  final double iconSize;

  const CourtNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.iconSize = 38,
  });

  @override
  State<CourtNetworkImage> createState() => _CourtNetworkImageState();
}

class _CourtNetworkImageState extends State<CourtNetworkImage> {
  bool _loggedError = false;

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      return _Placeholder(iconSize: widget.iconSize);
    }
    return Image.network(
      url,
      fit: widget.fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return _Placeholder(iconSize: widget.iconSize, isLoading: true);
      },
      errorBuilder: (_, error, stack) {
        if (kDebugMode && !_loggedError) {
          _loggedError = true;
          debugPrint('CourtNetworkImage: failed to load $url — $error');
        }
        return _Placeholder(iconSize: widget.iconSize);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double iconSize;
  final bool isLoading;

  const _Placeholder({required this.iconSize, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primaryLight,
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            )
          : Icon(
              Icons.sports_tennis_outlined,
              size: iconSize,
              color: AppColors.primary,
            ),
    );
  }
}
