import 'package:flutter/material.dart';
import '../tokens.dart';

/// Reusable image frame controls with arrows and dot indicators
/// Used across all race question types for car image navigation
class ImageFrameControls extends StatefulWidget {
  final int currentFrame;
  final int totalFrames;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool autoPlay;
  final VoidCallback? onAutoPlayToggle;
  final Color? arrowColor;
  final Color? activeDotColor;
  final Color? inactiveDotColor;

  const ImageFrameControls({
    super.key,
    required this.currentFrame,
    required this.totalFrames,
    required this.onPrevious,
    required this.onNext,
    this.autoPlay = false,
    this.onAutoPlayToggle,
    this.arrowColor,
    this.activeDotColor,
    this.inactiveDotColor,
  });

  @override
  State<ImageFrameControls> createState() => _ImageFrameControlsState();
}

class _ImageFrameControlsState extends State<ImageFrameControls> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: DesignTokens.durationSlow,
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.autoPlay) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ImageFrameControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Arrow controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous button
            _ArrowButton(
              icon: Icons.arrow_back_ios_rounded,
              onTap: widget.onPrevious,
              color: widget.arrowColor ?? DesignTokens.textPrimary,
            ),

            const SizedBox(width: DesignTokens.space24),

            // Auto-play toggle (if provided)
            if (widget.onAutoPlayToggle != null)
              ScaleTransition(
                scale: _pulseAnimation,
                child: _AutoPlayButton(
                  isPlaying: widget.autoPlay,
                  onTap: widget.onAutoPlayToggle!,
                ),
              ),

            if (widget.onAutoPlayToggle != null)
              const SizedBox(width: DesignTokens.space24),

            // Next button
            _ArrowButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: widget.onNext,
              color: widget.arrowColor ?? DesignTokens.textPrimary,
            ),
          ],
        ),

        const SizedBox(height: DesignTokens.space12),

        // Dot indicators
        _DotIndicators(
          currentFrame: widget.currentFrame,
          totalFrames: widget.totalFrames,
          activeColor: widget.activeDotColor ?? DesignTokens.primaryRed,
          inactiveColor: widget.inactiveDotColor ?? DesignTokens.textTertiary,
        ),
      ],
    );
  }
}

/// Arrow button with scale animation on press
class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ArrowButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: DesignTokens.durationInstant,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: DesignTokens.minTouchTarget,
          height: DesignTokens.minTouchTarget,
          decoration: BoxDecoration(
            color: DesignTokens.surfaceElevated,
            shape: BoxShape.circle,
            boxShadow: DesignTokens.shadowLevel1,
          ),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: DesignTokens.iconSizeMedium,
          ),
        ),
      ),
    );
  }
}

/// Auto-play button with play/pause icon
class _AutoPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _AutoPlayButton({
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_AutoPlayButton> createState() => _AutoPlayButtonState();
}

class _AutoPlayButtonState extends State<_AutoPlayButton> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: DesignTokens.durationInstant,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: DesignTokens.minTouchTarget,
          height: DesignTokens.minTouchTarget,
          decoration: BoxDecoration(
            color: widget.isPlaying ? DesignTokens.primaryRed : DesignTokens.surfaceElevated,
            shape: BoxShape.circle,
            boxShadow: DesignTokens.shadowLevel1,
          ),
          child: Icon(
            widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: DesignTokens.white,
            size: DesignTokens.iconSizeMedium,
          ),
        ),
      ),
    );
  }
}

/// Dot indicators showing current frame position
class _DotIndicators extends StatelessWidget {
  final int currentFrame;
  final int totalFrames;
  final Color activeColor;
  final Color inactiveColor;

  const _DotIndicators({
    required this.currentFrame,
    required this.totalFrames,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalFrames, (index) {
        final bool isActive = index == currentFrame;
        return AnimatedContainer(
          duration: DesignTokens.durationFast,
          curve: DesignTokens.curveDefault,
          width: isActive ? 12 : 8,
          height: isActive ? 12 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            shape: BoxShape.circle,
            boxShadow: isActive ? DesignTokens.shadowLevel1 : null,
          ),
        );
      }),
    );
  }
}

/// Animated image frame switcher with slide transition
class AnimatedFrameImage extends StatefulWidget {
  final String imagePath;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AnimatedFrameImage({
    super.key,
    required this.imagePath,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  State<AnimatedFrameImage> createState() => _AnimatedFrameImageState();
}

class _AnimatedFrameImageState extends State<AnimatedFrameImage> {
  @override
  void didUpdateWidget(AnimatedFrameImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Track image path changes for animation purposes
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? DesignTokens.borderRadiusMedium,
      child: Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor ?? DesignTokens.surface,
        child: AnimatedSwitcher(
          duration: DesignTokens.durationInstant,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: DesignTokens.curveDefault,
                )),
                child: child,
              ),
            );
          },
          child: Image.asset(
            widget.imagePath,
            key: ValueKey(widget.imagePath),
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: DesignTokens.surface,
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: DesignTokens.textTertiary,
                    size: DesignTokens.iconSizeLarge,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
