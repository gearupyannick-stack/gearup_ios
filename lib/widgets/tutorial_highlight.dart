import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A custom spotlight overlay that highlights a specific widget during tutorial
/// Shows a darkened screen with a spotlight cutout around the target element
/// and prompt text telling user to tap it
class TutorialHighlight extends StatelessWidget {
  /// The GlobalKey of the widget to highlight
  final GlobalKey targetKey;

  /// The prompt text to show (translation key)
  final String promptKey;

  /// Callback when the highlighted area is tapped
  final VoidCallback onTap;

  /// Optional padding around the highlighted region
  final double padding;

  const TutorialHighlight({
    Key? key,
    required this.targetKey,
    required this.promptKey,
    required this.onTap,
    this.padding = 10,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the position and size of the target widget
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // Target not yet rendered, return empty
      return const SizedBox.shrink();
    }

    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Calculate spotlight rectangle with padding
    final spotlightRect = Rect.fromLTWH(
      offset.dx - padding,
      offset.dy - padding,
      size.width + (padding * 2),
      size.height + (padding * 2),
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Darkened overlay with spotlight cutout
          GestureDetector(
            onTap: () {
              // Ignore taps outside spotlight
            },
            child: CustomPaint(
              painter: _SpotlightPainter(
                spotlightRect: spotlightRect,
                screenSize: screenSize,
              ),
              size: screenSize,
            ),
          ),

          // Tap detector for spotlight area only
          Positioned(
            left: spotlightRect.left,
            top: spotlightRect.top,
            width: spotlightRect.width,
            height: spotlightRect.height,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.orange,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Prompt text positioned below spotlight (or above if too low)
          Positioned(
            left: screenSize.width * 0.1,
            right: screenSize.width * 0.1,
            top: spotlightRect.bottom + 20 < screenSize.height * 0.7
                ? spotlightRect.bottom + 20
                : spotlightRect.top - 100,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.95),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.touch_app,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      promptKey.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws a darkened overlay with a spotlight cutout
class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final Size screenSize;

  _SpotlightPainter({
    required this.spotlightRect,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw darkened overlay
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Create path for entire screen
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height));

    // Create rounded rectangle for spotlight cutout
    final spotlightPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        spotlightRect,
        const Radius.circular(12),
      ));

    // Subtract spotlight from overlay
    final finalPath = Path.combine(
      PathOperation.difference,
      path,
      spotlightPath,
    );

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
