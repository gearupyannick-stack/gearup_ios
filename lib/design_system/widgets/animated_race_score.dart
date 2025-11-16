import 'package:flutter/material.dart';
import '../tokens.dart';
import 'dart:math' as math;

/// Animated score display with streak effects and score change animations
/// Shows pulsing effects, streak indicators, and motivational messages
class AnimatedRaceScore extends StatefulWidget {
  final int currentScore;
  final int totalQuestions;
  final int currentStreak;
  final bool showScoreChange;
  final bool wasCorrect;
  final String? customMessage;

  const AnimatedRaceScore({
    super.key,
    required this.currentScore,
    required this.totalQuestions,
    this.currentStreak = 0,
    this.showScoreChange = false,
    this.wasCorrect = false,
    this.customMessage,
  });

  @override
  State<AnimatedRaceScore> createState() => _AnimatedRaceScoreState();
}

class _AnimatedRaceScoreState extends State<AnimatedRaceScore>
    with TickerProviderStateMixin {
  late AnimationController _scoreChangeController;
  late AnimationController _streakController;
  late AnimationController _pulseController;

  late Animation<double> _scoreScaleAnimation;
  late Animation<double> _scoreOpacityAnimation;
  late Animation<Offset> _scoreSlideAnimation;
  late Animation<double> _streakBounceAnimation;
  late Animation<double> _pulseAnimation;

  int _displayedScore = 0;

  @override
  void initState() {
    super.initState();
    _displayedScore = widget.currentScore;

    // Score change animation (when correct/incorrect answer)
    _scoreChangeController = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _scoreScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _scoreChangeController,
        curve: DesignTokens.curveElastic,
      ),
    );

    _scoreOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _scoreChangeController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _scoreSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.5),
    ).animate(
      CurvedAnimation(
        parent: _scoreChangeController,
        curve: Curves.easeOut,
      ),
    );

    // Streak celebration animation
    _streakController = AnimationController(
      duration: DesignTokens.durationSlow,
      vsync: this,
    );

    _streakBounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _streakController,
        curve: Curves.elasticOut,
      ),
    );

    // Continuous pulse for high streaks
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    // Auto-pulse on high streaks
    if (widget.currentStreak >= 3) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedRaceScore oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate score change
    if (widget.currentScore != oldWidget.currentScore && widget.showScoreChange) {
      _scoreChangeController.forward(from: 0);
      _displayedScore = widget.currentScore;
    }

    // Animate streak milestones
    if (widget.currentStreak != oldWidget.currentStreak && widget.currentStreak > 0) {
      if (widget.currentStreak % 3 == 0) {
        // Celebration at 3, 6, 9, etc.
        _streakController.forward(from: 0);
      }
    }

    // Control pulse based on streak
    if (widget.currentStreak >= 3 && oldWidget.currentStreak < 3) {
      _pulseController.repeat(reverse: true);
    } else if (widget.currentStreak < 3 && oldWidget.currentStreak >= 3) {
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _scoreChangeController.dispose();
    _streakController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _getStreakMessage() {
    if (widget.customMessage != null) return widget.customMessage!;

    if (widget.currentStreak >= 10) {
      return 'UNSTOPPABLE!';
    } else if (widget.currentStreak >= 7) {
      return 'LEGENDARY!';
    } else if (widget.currentStreak >= 5) {
      return 'ON FIRE!';
    } else if (widget.currentStreak >= 3) {
      return 'HOT STREAK!';
    }
    return '';
  }

  Color _getStreakColor() {
    if (widget.currentStreak >= 7) {
      return DesignTokens.accentGold;
    } else if (widget.currentStreak >= 3) {
      return DesignTokens.streakOrange;
    }
    return DesignTokens.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasStreak = widget.currentStreak >= 3;
    final String streakMessage = _getStreakMessage();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.space16,
        vertical: DesignTokens.space12,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceElevated,
        borderRadius: DesignTokens.borderRadiusMedium,
        boxShadow: DesignTokens.shadowLevel1,
        border: hasStreak
            ? Border.all(
                color: _getStreakColor().withOpacity(0.5),
                width: 2,
              )
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Score display
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // Score animation
              Stack(
                alignment: Alignment.center,
                children: [
                  // Main score
                  ScaleTransition(
                    scale: widget.currentStreak >= 3
                        ? _pulseAnimation
                        : _scoreScaleAnimation,
                    child: Text(
                      '$_displayedScore',
                      style: DesignTokens.heading1.copyWith(
                        color: hasStreak
                            ? _getStreakColor()
                            : DesignTokens.textPrimary,
                        fontWeight: DesignTokens.weightBold,
                      ),
                    ),
                  ),

                  // Score change indicator (+1 or nothing)
                  if (widget.showScoreChange && widget.wasCorrect)
                    SlideTransition(
                      position: _scoreSlideAnimation,
                      child: FadeTransition(
                        opacity: _scoreOpacityAnimation,
                        child: Text(
                          '+1',
                          style: DesignTokens.heading2.copyWith(
                            color: DesignTokens.success,
                            fontWeight: DesignTokens.weightBold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              Text(
                ' / ${widget.totalQuestions}',
                style: DesignTokens.heading3.copyWith(
                  color: DesignTokens.textSecondary,
                ),
              ),
            ],
          ),

          // Streak indicator
          if (widget.currentStreak > 0) ...[
            const SizedBox(height: DesignTokens.space8),
            ScaleTransition(
              scale: hasStreak ? _streakBounceAnimation : const AlwaysStoppedAnimation(1.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Fire icon for streaks
                  if (hasStreak)
                    _AnimatedFlame(
                      isActive: hasStreak,
                      color: _getStreakColor(),
                    ),

                  if (hasStreak) const SizedBox(width: DesignTokens.space4),

                  // Streak count
                  Text(
                    '${widget.currentStreak} streak',
                    style: DesignTokens.bodyMedium.copyWith(
                      color: hasStreak ? _getStreakColor() : DesignTokens.textSecondary,
                      fontWeight: hasStreak
                          ? DesignTokens.weightBold
                          : DesignTokens.weightMedium,
                    ),
                  ),

                  if (hasStreak) const SizedBox(width: DesignTokens.space4),

                  if (hasStreak)
                    _AnimatedFlame(
                      isActive: hasStreak,
                      color: _getStreakColor(),
                    ),
                ],
              ),
            ),
          ],

          // Streak message
          if (streakMessage.isNotEmpty) ...[
            const SizedBox(height: DesignTokens.space4),
            _ShimmeringText(
              text: streakMessage,
              baseColor: _getStreakColor(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Animated flame icon for streak indicator
class _AnimatedFlame extends StatefulWidget {
  final bool isActive;
  final Color color;

  const _AnimatedFlame({
    required this.isActive,
    required this.color,
  });

  @override
  State<_AnimatedFlame> createState() => _AnimatedFlameState();
}

class _AnimatedFlameState extends State<_AnimatedFlame>
    with SingleTickerProviderStateMixin {
  late AnimationController _flickerController;
  late Animation<double> _flickerAnimation;

  @override
  void initState() {
    super.initState();
    _flickerController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _flickerAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _flickerController,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isActive) {
      _flickerController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_AnimatedFlame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _flickerController.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _flickerController.reset();
    }
  }

  @override
  void dispose() {
    _flickerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _flickerAnimation,
      child: Icon(
        Icons.local_fire_department,
        color: widget.color,
        size: DesignTokens.iconSizeMedium,
        shadows: [
          Shadow(
            color: widget.color.withOpacity(0.5),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// Shimmering text for streak messages
class _ShimmeringText extends StatefulWidget {
  final String text;
  final Color baseColor;

  const _ShimmeringText({
    required this.text,
    required this.baseColor,
  });

  @override
  State<_ShimmeringText> createState() => _ShimmeringTextState();
}

class _ShimmeringTextState extends State<_ShimmeringText>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.linear,
      ),
    );

    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.baseColor,
                widget.baseColor.withOpacity(0.6),
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: GradientRotation(_shimmerAnimation.value),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.white,
              fontWeight: DesignTokens.weightBold,
              letterSpacing: 1.5,
            ),
          ),
        );
      },
    );
  }
}

/// Score change particle effect (confetti/sparkles)
class ScoreChangeParticles extends StatefulWidget {
  final bool trigger;
  final bool wasCorrect;

  const ScoreChangeParticles({
    super.key,
    required this.trigger,
    required this.wasCorrect,
  });

  @override
  State<ScoreChangeParticles> createState() => _ScoreChangeParticlesState();
}

class _ScoreChangeParticlesState extends State<ScoreChangeParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _particleController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(ScoreChangeParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _createParticles();
      _particleController.forward(from: 0);
    }
  }

  void _createParticles() {
    _particles.clear();
    final random = math.Random();

    if (widget.wasCorrect) {
      // Confetti for correct answers
      for (int i = 0; i < 15; i++) {
        _particles.add(_Particle(
          color: [
            DesignTokens.success,
            DesignTokens.accentGold,
            DesignTokens.primaryRed,
            DesignTokens.info,
          ][random.nextInt(4)],
          angle: random.nextDouble() * 2 * math.pi,
          speed: 100 + random.nextDouble() * 150,
        ));
      }
    }
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(200, 200),
      painter: _ParticlePainter(
        particles: _particles,
        progress: _particleController.value,
      ),
    );
  }
}

class _Particle {
  final Color color;
  final double angle;
  final double speed;

  _Particle({
    required this.color,
    required this.angle,
    required this.speed,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final distance = particle.speed * progress;
      final x = center.dx + math.cos(particle.angle) * distance;
      final y = center.dy + math.sin(particle.angle) * distance + (progress * progress * 100); // Gravity

      final opacity = 1.0 - progress;
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 4, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) => true;
}
