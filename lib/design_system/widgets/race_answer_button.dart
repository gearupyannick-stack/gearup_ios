import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';

/// Enhanced answer button with animations and feedback states
/// Supports correct/incorrect states, disabled mode, and haptic feedback
class RaceAnswerButton extends StatefulWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isDisabled;
  final ButtonFeedbackState feedbackState;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool enableHaptics;

  const RaceAnswerButton({
    super.key,
    required this.text,
    this.onTap,
    this.isDisabled = false,
    this.feedbackState = ButtonFeedbackState.none,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.padding,
    this.enableHaptics = true,
  });

  @override
  State<RaceAnswerButton> createState() => _RaceAnswerButtonState();
}

class _RaceAnswerButtonState extends State<RaceAnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: DesignTokens.curveDefault,
      ),
    );

    // Shake animation for incorrect answers
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(RaceAnswerButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger animations based on feedback state
    if (widget.feedbackState != oldWidget.feedbackState) {
      if (widget.feedbackState == ButtonFeedbackState.correct) {
        _triggerCorrectAnimation();
      } else if (widget.feedbackState == ButtonFeedbackState.incorrect) {
        _triggerIncorrectAnimation();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _triggerCorrectAnimation() {
    _controller.forward().then((_) {
      if (mounted) {
        _controller.reverse();
      }
    });

    // Haptic feedback
    if (widget.enableHaptics) {
      HapticFeedback.mediumImpact();
    }
  }

  void _triggerIncorrectAnimation() {
    _controller.forward().then((_) {
      if (mounted) {
        _controller.reverse();
      }
    });

    // Haptic feedback
    if (widget.enableHaptics) {
      HapticFeedback.heavyImpact();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled && widget.feedbackState == ButtonFeedbackState.none) {
      setState(() => _isPressed = true);
      _controller.forward();

      if (widget.enableHaptics) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  Color _getBackgroundColor() {
    if (widget.feedbackState == ButtonFeedbackState.correct) {
      return DesignTokens.success;
    } else if (widget.feedbackState == ButtonFeedbackState.incorrect) {
      return DesignTokens.error;
    } else if (widget.isDisabled) {
      return (widget.backgroundColor ?? DesignTokens.surfaceElevated)
          .withOpacity(DesignTokens.opacityDisabled);
    }
    return widget.backgroundColor ?? DesignTokens.surfaceElevated;
  }

  Color _getTextColor() {
    if (widget.feedbackState != ButtonFeedbackState.none) {
      return DesignTokens.white;
    } else if (widget.isDisabled) {
      return DesignTokens.textDisabled;
    }
    return widget.textColor ?? DesignTokens.textPrimary;
  }

  Widget _buildFeedbackIcon() {
    if (widget.feedbackState == ButtonFeedbackState.correct) {
      return const Icon(
        Icons.check_circle,
        color: DesignTokens.white,
        size: DesignTokens.iconSizeMedium,
      );
    } else if (widget.feedbackState == ButtonFeedbackState.incorrect) {
      return const Icon(
        Icons.cancel,
        color: DesignTokens.white,
        size: DesignTokens.iconSizeMedium,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.isDisabled ||
              widget.feedbackState != ButtonFeedbackState.none
          ? null
          : widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Apply shake for incorrect, scale for pressed/correct
          final transform = Matrix4.identity();

          if (widget.feedbackState == ButtonFeedbackState.incorrect) {
            transform.translate(_shakeAnimation.value, 0.0, 0.0);
          } else {
            transform.scale(_scaleAnimation.value);
          }

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: DesignTokens.durationFast,
              curve: DesignTokens.curveDefault,
              height: widget.height ?? DesignTokens.buttonHeightMedium,
              padding: widget.padding ?? DesignTokens.paddingHorizontalLarge,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: DesignTokens.borderRadiusMedium,
                boxShadow: widget.isDisabled ||
                        widget.feedbackState != ButtonFeedbackState.none
                    ? null
                    : DesignTokens.shadowLevel2,
                border: widget.feedbackState != ButtonFeedbackState.none
                    ? Border.all(
                        color: DesignTokens.white.withOpacity(0.3),
                        width: 2,
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.text,
                      style: DesignTokens.button.copyWith(
                        color: _getTextColor(),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                  if (widget.feedbackState != ButtonFeedbackState.none) ...[
                    const SizedBox(width: DesignTokens.space8),
                    _buildFeedbackIcon(),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Button feedback states
enum ButtonFeedbackState {
  none,
  correct,
  incorrect,
}

/// Grid of answer buttons (common pattern in race questions)
class AnswerButtonGrid extends StatelessWidget {
  final List<String> options;
  final Function(int) onOptionSelected;
  final int? selectedIndex;
  final int? correctIndex;
  final bool isDisabled;
  final int crossAxisCount;

  const AnswerButtonGrid({
    super.key,
    required this.options,
    required this.onOptionSelected,
    this.selectedIndex,
    this.correctIndex,
    this.isDisabled = false,
    this.crossAxisCount = 2,
  });

  ButtonFeedbackState _getFeedbackState(int index) {
    if (selectedIndex == null) return ButtonFeedbackState.none;

    if (correctIndex != null) {
      if (index == correctIndex) {
        return ButtonFeedbackState.correct;
      } else if (index == selectedIndex && index != correctIndex) {
        return ButtonFeedbackState.incorrect;
      }
    } else if (index == selectedIndex) {
      // Show feedback immediately if no correctIndex provided
      return ButtonFeedbackState.correct;
    }

    return ButtonFeedbackState.none;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: DesignTokens.space12,
        mainAxisSpacing: DesignTokens.space12,
        childAspectRatio: 2.5,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        return RaceAnswerButton(
          text: options[index],
          onTap: () => onOptionSelected(index),
          isDisabled: isDisabled || selectedIndex != null,
          feedbackState: _getFeedbackState(index),
        );
      },
    );
  }
}

/// List of answer buttons (vertical layout)
class AnswerButtonList extends StatelessWidget {
  final List<String> options;
  final Function(int) onOptionSelected;
  final int? selectedIndex;
  final int? correctIndex;
  final bool isDisabled;
  final double spacing;

  const AnswerButtonList({
    super.key,
    required this.options,
    required this.onOptionSelected,
    this.selectedIndex,
    this.correctIndex,
    this.isDisabled = false,
    this.spacing = DesignTokens.space12,
  });

  ButtonFeedbackState _getFeedbackState(int index) {
    if (selectedIndex == null) return ButtonFeedbackState.none;

    if (correctIndex != null) {
      if (index == correctIndex) {
        return ButtonFeedbackState.correct;
      } else if (index == selectedIndex && index != correctIndex) {
        return ButtonFeedbackState.incorrect;
      }
    } else if (index == selectedIndex) {
      return ButtonFeedbackState.correct;
    }

    return ButtonFeedbackState.none;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(options.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < options.length - 1 ? spacing : 0,
          ),
          child: RaceAnswerButton(
            text: options[index],
            onTap: () => onOptionSelected(index),
            isDisabled: isDisabled || selectedIndex != null,
            feedbackState: _getFeedbackState(index),
          ),
        );
      }),
    );
  }
}

/// Compact answer button for smaller spaces
class CompactAnswerButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isCorrect;
  final bool isDisabled;

  const CompactAnswerButton({
    super.key,
    required this.text,
    this.onTap,
    this.isSelected = false,
    this.isCorrect = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    if (isSelected && isCorrect) {
      backgroundColor = DesignTokens.success;
      textColor = DesignTokens.white;
    } else if (isSelected && !isCorrect) {
      backgroundColor = DesignTokens.error;
      textColor = DesignTokens.white;
    } else if (isDisabled) {
      backgroundColor = DesignTokens.surfaceElevated.withOpacity(DesignTokens.opacityDisabled);
      textColor = DesignTokens.textDisabled;
    } else {
      backgroundColor = DesignTokens.surfaceElevated;
      textColor = DesignTokens.textPrimary;
    }

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: DesignTokens.borderRadiusSmall,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space16,
          vertical: DesignTokens.space8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: DesignTokens.borderRadiusSmall,
          border: isSelected
              ? Border.all(color: DesignTokens.white.withOpacity(0.3), width: 2)
              : null,
        ),
        child: Text(
          text,
          style: DesignTokens.bodySmall.copyWith(
            color: textColor,
            fontWeight: DesignTokens.weightMedium,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
