import 'package:flutter/material.dart';
import '../tokens.dart';

/// Shimmer loading effect for skeleton screens
/// Provides smooth animated loading placeholders
class LoadingShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration? duration;

  const LoadingShimmer({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
    this.duration,
  });

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );

    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(LoadingShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor ?? DesignTokens.surfaceElevated,
                widget.highlightColor ?? DesignTokens.surfaceHighlighted,
                widget.baseColor ?? DesignTokens.surfaceElevated,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(slidePercent: _animation.value),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}

/// Pre-built shimmer skeleton for common UI elements
class ShimmerSkeleton {
  ShimmerSkeleton._();

  /// Rectangular skeleton placeholder
  static Widget rectangle({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height ?? 16,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.surfaceElevated,
        borderRadius: borderRadius ?? DesignTokens.borderRadiusSmall,
      ),
    );
  }

  /// Circular skeleton placeholder
  static Widget circle({
    double? size,
    Color? color,
  }) {
    final diameter = size ?? 48;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.surfaceElevated,
        shape: BoxShape.circle,
      ),
    );
  }

  /// Text line skeleton
  static Widget textLine({
    double? width,
    double height = 14,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? DesignTokens.surfaceElevated,
        borderRadius: DesignTokens.borderRadiusSmall,
      ),
    );
  }

  /// Card skeleton with multiple elements
  static Widget card({
    double? height,
    bool showAvatar = false,
    int lines = 3,
  }) {
    return Container(
      height: height,
      padding: DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: DesignTokens.borderRadiusMedium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar)
            Row(
              children: [
                circle(size: 40),
                const SizedBox(width: DesignTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      textLine(width: 120),
                      const SizedBox(height: DesignTokens.space4),
                      textLine(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          if (showAvatar) const SizedBox(height: DesignTokens.space16),
          ...List.generate(
            lines,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index < lines - 1 ? DesignTokens.space8 : 0,
              ),
              child: textLine(
                width: index == lines - 1 ? 150 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Button skeleton
  static Widget button({
    double? width,
    double height = DesignTokens.buttonHeightMedium,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated,
        borderRadius: DesignTokens.borderRadiusMedium,
      ),
    );
  }

  /// Image skeleton
  static Widget image({
    double? width,
    double? height,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: width,
      height: height ?? 200,
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated,
        borderRadius: borderRadius ?? DesignTokens.borderRadiusMedium,
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: DesignTokens.iconSizeLarge,
          color: DesignTokens.textTertiary,
        ),
      ),
    );
  }
}

/// Loading skeleton for race waiting screen
class RaceWaitingSkeleton extends StatelessWidget {
  const RaceWaitingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Track preview skeleton
          ShimmerSkeleton.image(
            height: 200,
            borderRadius: DesignTokens.borderRadiusLarge,
          ),

          const SizedBox(height: DesignTokens.space32),

          // Player cards skeleton
          ...List.generate(
            2,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.space12),
              child: ShimmerSkeleton.card(
                height: 80,
                showAvatar: true,
                lines: 1,
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.space32),

          // Status text skeleton
          ShimmerSkeleton.textLine(width: 200, height: 16),

          const SizedBox(height: DesignTokens.space16),

          // Countdown skeleton
          ShimmerSkeleton.circle(size: 60),
        ],
      ),
    );
  }
}

/// Loading skeleton for track selection
class TrackSelectionSkeleton extends StatelessWidget {
  final int count;

  const TrackSelectionSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: DesignTokens.space12,
          mainAxisSpacing: DesignTokens.space12,
          childAspectRatio: 1.5,
        ),
        itemCount: count,
        itemBuilder: (context, index) {
          return ShimmerSkeleton.image(
            borderRadius: DesignTokens.borderRadiusLarge,
          );
        },
      ),
    );
  }
}

/// Pulsing loading indicator (alternative to shimmer)
class PulsingLoader extends StatefulWidget {
  final Widget child;
  final Color? color;
  final Duration? duration;

  const PulsingLoader({
    super.key,
    required this.child,
    this.color,
    this.duration,
  });

  @override
  State<PulsingLoader> createState() => _PulsingLoaderState();
}

class _PulsingLoaderState extends State<PulsingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration ?? DesignTokens.durationSlow,
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// Spinning circular progress indicator
class SpinningLoader extends StatelessWidget {
  final double? size;
  final Color? color;
  final double strokeWidth;

  const SpinningLoader({
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size ?? 24,
      height: size ?? 24,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? DesignTokens.primaryRed,
        ),
      ),
    );
  }
}

/// Dots loading indicator
class DotsLoader extends StatefulWidget {
  final int dotCount;
  final Color? color;
  final double size;
  final double spacing;

  const DotsLoader({
    super.key,
    this.dotCount = 3,
    this.color,
    this.size = 8,
    this.spacing = 8,
  });

  @override
  State<DotsLoader> createState() => _DotsLoaderState();
}

class _DotsLoaderState extends State<DotsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.durationSlow,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.dotCount, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress = (_controller.value - (index * 0.2)) % 1.0;
            final scale = 0.5 + (0.5 * (1 - (progress - 0.5).abs() * 2));

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: (widget.color ?? DesignTokens.primaryRed)
                        .withOpacity(0.5 + (scale - 0.5)),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
