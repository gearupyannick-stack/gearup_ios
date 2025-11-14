// lib/widgets/challenge_completion_dialog.dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ChallengeCompletionDialog extends StatefulWidget {
  final int correctAnswers;
  final int totalQuestions;
  final int totalSeconds;
  final VoidCallback onClose;

  const ChallengeCompletionDialog({
    Key? key,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.totalSeconds,
    required this.onClose,
  }) : super(key: key);

  @override
  State<ChallengeCompletionDialog> createState() =>
      _ChallengeCompletionDialogState();
}

class _ChallengeCompletionDialogState extends State<ChallengeCompletionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _starAnimation;

  int get stars {
    final percentage = (widget.correctAnswers / widget.totalQuestions) * 100;
    if (percentage >= 90) return 3;
    if (percentage >= 70) return 2;
    if (percentage >= 50) return 1;
    return 0;
  }

  String get medalEmoji {
    final percentage = (widget.correctAnswers / widget.totalQuestions) * 100;
    if (percentage == 100) return '🏆'; // Perfect
    if (percentage >= 85) return '🥇'; // Gold
    if (percentage >= 70) return '🥈'; // Silver
    if (percentage >= 50) return '🥉'; // Bronze
    return '📊'; // Participation
  }

  String get performanceMessage {
    final percentage = (widget.correctAnswers / widget.totalQuestions) * 100;
    if (percentage == 100) return 'challenges.perfect'.tr();
    if (percentage >= 90) return 'challenges.excellent'.tr();
    if (percentage >= 80) return 'challenges.great'.tr();
    if (percentage >= 70) return 'challenges.good'.tr();
    if (percentage >= 50) return 'challenges.notBad'.tr();
    return 'challenges.keepPracticing'.tr();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _starAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.totalSeconds ~/ 60;
    final seconds = widget.totalSeconds % 60;
    final avgTimePerQuestion = widget.totalSeconds / widget.totalQuestions;
    final accuracy =
        ((widget.correctAnswers / widget.totalQuestions) * 100).toStringAsFixed(1);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[900]!,
              Colors.grey[850]!,
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Medal/Trophy
            ScaleTransition(
              scale: _scaleAnimation,
              child: Text(
                medalEmoji,
                style: const TextStyle(fontSize: 80),
              ),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              'challenges.complete'.tr(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            // Performance Message
            Text(
              performanceMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),

            const SizedBox(height: 16),

            // Stars
            ScaleTransition(
              scale: _starAnimation,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Icon(
                    index < stars ? Icons.star : Icons.star_border,
                    color: index < stars ? Colors.amber : Colors.grey[600],
                    size: 40,
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.correctAnswers}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '/${widget.totalQuestions}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Statistics
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStatRow(
                    Icons.timer_outlined,
                    'challenges.totalTime'.tr(),
                    '${minutes}m ${seconds.toString().padLeft(2, '0')}s',
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.speed,
                    'challenges.avgTime'.tr(),
                    '${avgTimePerQuestion.toStringAsFixed(1)}s',
                  ),
                  const SizedBox(height: 8),
                  _buildStatRow(
                    Icons.percent,
                    'challenges.accuracy'.tr(),
                    '$accuracy%',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // OK Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue,
                ),
                child: Text(
                  'common.ok'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
