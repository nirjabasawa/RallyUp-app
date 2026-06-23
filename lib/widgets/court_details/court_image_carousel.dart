import 'package:flutter/material.dart';

import '../courts/court_network_image.dart';

/// Swipeable image gallery for the Court Details hero area.
///
/// Behavior:
///   * Multiple images → horizontal `PageView` with a small dot
///     indicator overlay so the user can see they can swipe.
///   * Single image → renders one full-bleed image, no controls.
///   * Empty list / all-network-failures → clean RallyUp-style
///     placeholder, never a broken-image icon.
///
/// The widget owns its own page controller and indicator state; the
/// caller only needs to pass the URLs.
class CourtImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;

  const CourtImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 210,
  });

  @override
  State<CourtImageCarousel> createState() => _CourtImageCarouselState();
}

class _CourtImageCarouselState extends State<CourtImageCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    if (urls.isEmpty) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: const CourtNetworkImage(url: null, iconSize: 44),
      );
    }

    if (urls.length == 1) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: CourtNetworkImage(url: urls.first, iconSize: 44),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) =>
                CourtNetworkImage(url: urls[i], iconSize: 44),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
