// lib/widgets/animated_score_display.dart
import 'package:flutter/material.dart';

class AnimatedScoreDisplay extends StatefulWidget {
  final int currentScore;
  final int totalQuestions;
  final int currentStreak;
  final bool showScoreChange;
  final bool wasCorrect;

  const AnimatedScoreDisplay({
    Key? key,
    required this.currentScore,
    required this.totalQuestions,
    required this.currentStreak,
    this.showScoreChange = false,
    this.wasCorrect = false,
  }) : super(key: key);

  @override
  State<AnimatedScoreDisplay> createState() => _AnimatedScoreDisplayState();
}

class _AnimatedScoreDisplayState extends State<AnimatedScoreDisplay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.elasticOut,
      ),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.elasticIn,
      ),
    );
  }

  @override
  void didUpdateWidget(AnimatedScoreDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showScoreChange && widget.currentScore != oldWidget.currentScore) {
      if (widget.wasCorrect) {
        _pulseController.forward(from: 0);
      } else {
        _shakeController.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Score display
        AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _shakeController]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeAnimation.value * (widget.wasCorrect ? 0 : 1), 0),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${widget.currentScore}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: widget.wasCorrect && widget.showScoreChange
                            ? Colors.green
                            : Colors.white,
                      ),
                    ),
                    Text(
                      '/${widget.totalQuestions}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    if (widget.showScoreChange && widget.wasCorrect)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Text(
                          '+1',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.withOpacity(
                              1.0 - _pulseController.value,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        // Streak display
        if (widget.currentStreak > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.currentStreak} streak!',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
