import 'package:flutter/material.dart';
import '../tokens.dart';

/// Progress bar showing race question progress with color-coded dots
/// Green for correct, red for incorrect, highlighted for current, grey for upcoming
class RaceProgressBar extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final List<bool?> answeredCorrectly; // null = not answered yet, true/false = result
  final bool showPosition;
  final int? currentPosition; // 1st, 2nd, 3rd, etc.

  const RaceProgressBar({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.answeredCorrectly,
    this.showPosition = false,
    this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space12,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated,
        borderRadius: DesignTokens.borderRadiusMedium,
        boxShadow: DesignTokens.shadowLevel1,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Position indicator (if racing)
          if (showPosition && currentPosition != null) ...[
            _PositionIndicator(position: currentPosition!),
            const SizedBox(height: DesignTokens.space8),
          ],

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate spacing to fit all dots
                    final double availableWidth = constraints.maxWidth;
                    final double dotSize = 12.0;
                    final double totalDotsWidth = totalQuestions * dotSize;
                    final double spacing = totalQuestions > 1
                        ? (availableWidth - totalDotsWidth) / (totalQuestions - 1)
                        : 0;
                    final double clampedSpacing = spacing.clamp(4.0, 12.0);

                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: clampedSpacing,
                      children: List.generate(totalQuestions, (index) {
                        return _ProgressDot(
                          isActive: index == currentQuestion,
                          wasCorrect: index < answeredCorrectly.length
                              ? answeredCorrectly[index]
                              : null,
                          index: index,
                        );
                      }),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: DesignTokens.space8),

          // Question counter text
          Text(
            'Question ${currentQuestion + 1} of $totalQuestions',
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.textSecondary,
              fontWeight: DesignTokens.weightMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual progress dot with animation
class _ProgressDot extends StatefulWidget {
  final bool isActive;
  final bool? wasCorrect; // null = not answered, true/false = result
  final int index;

  const _ProgressDot({
    required this.isActive,
    required this.wasCorrect,
    required this.index,
  });

  @override
  State<_ProgressDot> createState() => _ProgressDotState();
}

class _ProgressDotState extends State<_ProgressDot> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: DesignTokens.durationSlow,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    if (widget.isActive) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_ProgressDot oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Start pulse when becoming active
    if (widget.isActive && !oldWidget.isActive) {
      _pulseController.repeat(reverse: true);
    }

    // Stop pulse when no longer active
    if (!widget.isActive && oldWidget.isActive) {
      _pulseController.reset();
    }

    // Animate when answer is recorded
    if (widget.wasCorrect != null && oldWidget.wasCorrect == null) {
      _pulseController.forward(from: 0).then((_) {
        if (mounted) {
          _pulseController.reset();
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getDotColor() {
    if (widget.wasCorrect == true) {
      return DesignTokens.success;
    } else if (widget.wasCorrect == false) {
      return DesignTokens.error;
    } else if (widget.isActive) {
      return DesignTokens.primaryRed;
    } else {
      return DesignTokens.textTertiary;
    }
  }

  Widget _buildDot() {
    return Container(
      width: widget.isActive ? 14 : 12,
      height: widget.isActive ? 14 : 12,
      decoration: BoxDecoration(
        color: _getDotColor(),
        shape: BoxShape.circle,
        boxShadow: widget.isActive ? DesignTokens.shadowLevel2 : null,
        border: widget.isActive
            ? Border.all(color: DesignTokens.white, width: 2)
            : null,
      ),
      child: widget.wasCorrect == true
          ? const Icon(
              Icons.check,
              size: 8,
              color: DesignTokens.white,
            )
          : widget.wasCorrect == false
              ? const Icon(
                  Icons.close,
                  size: 8,
                  color: DesignTokens.white,
                )
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isActive) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: _buildDot(),
      );
    } else if (widget.wasCorrect != null) {
      return ScaleTransition(
        scale: _scaleAnimation,
        child: _buildDot(),
      );
    } else {
      return _buildDot();
    }
  }
}

/// Position indicator showing current race position
class _PositionIndicator extends StatelessWidget {
  final int position;

  const _PositionIndicator({required this.position});

  String _getOrdinalSuffix(int position) {
    if (position % 100 >= 11 && position % 100 <= 13) {
      return 'th';
    }
    switch (position % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Color _getPositionColor() {
    switch (position) {
      case 1:
        return DesignTokens.position1st;
      case 2:
        return DesignTokens.position2nd;
      case 3:
        return DesignTokens.position3rd;
      default:
        return DesignTokens.textSecondary;
    }
  }

  String _getMedal() {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (position <= 3) ...[
          Text(
            _getMedal(),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: DesignTokens.space8),
        ],
        Text(
          '$position${_getOrdinalSuffix(position)} Place',
          style: DesignTokens.bodyMedium.copyWith(
            color: _getPositionColor(),
            fontWeight: DesignTokens.weightBold,
          ),
        ),
      ],
    );
  }
}

/// Compact progress bar variant for minimal space usage
class CompactRaceProgressBar extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int correctAnswers;
  final Color? progressColor;
  final Color? backgroundColor;

  const CompactRaceProgressBar({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.correctAnswers,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final double accuracy = currentQuestion > 0 ? correctAnswers / currentQuestion : 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Accuracy and progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$correctAnswers/$currentQuestion correct',
              style: DesignTokens.caption.copyWith(
                color: DesignTokens.textSecondary,
              ),
            ),
            Text(
              '${(accuracy * 100).toStringAsFixed(0)}%',
              style: DesignTokens.caption.copyWith(
                color: accuracy >= 0.7 ? DesignTokens.success : DesignTokens.warning,
                fontWeight: DesignTokens.weightBold,
              ),
            ),
          ],
        ),

        const SizedBox(height: DesignTokens.space4),

        // Progress bar
        ClipRRect(
          borderRadius: DesignTokens.borderRadiusFull,
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                // Background
                Container(
                  color: backgroundColor ?? DesignTokens.surfaceHighlighted,
                ),
                // Progress fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: AnimatedContainer(
                    duration: DesignTokens.durationMedium,
                    curve: DesignTokens.curveDefault,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor ?? DesignTokens.primaryRed,
                          (progressColor ?? DesignTokens.primaryRed).withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Vertical progress bar for side-mounted race progress
/// Grows upward as progress increases
class VerticalRaceProgressBar extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final int correctAnswers;
  final Color? progressColor;
  final Color? backgroundColor;
  final double width;

  const VerticalRaceProgressBar({
    super.key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.correctAnswers,
    this.progressColor,
    this.backgroundColor,
    this.width = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = currentQuestion / totalQuestions;
    final double accuracy = currentQuestion > 0 ? correctAnswers / currentQuestion : 0;

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(
        vertical: DesignTokens.space8,
        horizontal: DesignTokens.space4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DesignTokens.black.withOpacity(0.6),
            DesignTokens.black.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(DesignTokens.radiusMedium),
        ),
        boxShadow: DesignTokens.shadowLevel2,
      ),
      child: Column(
        children: [
          // Question counter
          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: DesignTokens.primaryRed.withOpacity(0.2),
              borderRadius: DesignTokens.borderRadiusSmall,
            ),
            child: Text(
              '$currentQuestion\n$totalQuestions',
              style: DesignTokens.caption.copyWith(
                color: DesignTokens.textPrimary,
                fontWeight: DesignTokens.weightBold,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: DesignTokens.space8),

          // Vertical progress bar (grows upward)
          Expanded(
            child: ClipRRect(
              borderRadius: DesignTokens.borderRadiusFull,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Background
                  Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: backgroundColor ?? DesignTokens.surfaceHighlighted,
                      borderRadius: DesignTokens.borderRadiusFull,
                    ),
                  ),
                  // Progress fill (from bottom to top)
                  FractionallySizedBox(
                    heightFactor: progress,
                    child: AnimatedContainer(
                      duration: DesignTokens.durationMedium,
                      curve: DesignTokens.curveDefault,
                      width: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            progressColor ?? DesignTokens.primaryRed,
                            (progressColor ?? DesignTokens.primaryRed).withOpacity(0.7),
                          ],
                        ),
                        borderRadius: DesignTokens.borderRadiusFull,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: DesignTokens.space8),

          // Accuracy indicator
          Container(
            padding: const EdgeInsets.all(DesignTokens.space4),
            decoration: BoxDecoration(
              color: accuracy >= 0.7
                ? DesignTokens.success.withOpacity(0.2)
                : DesignTokens.warning.withOpacity(0.2),
              borderRadius: DesignTokens.borderRadiusSmall,
            ),
            child: Text(
              '${(accuracy * 100).toStringAsFixed(0)}%',
              style: DesignTokens.caption.copyWith(
                color: accuracy >= 0.7 ? DesignTokens.success : DesignTokens.warning,
                fontWeight: DesignTokens.weightBold,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
