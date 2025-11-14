// lib/widgets/question_progress_bar.dart
import 'package:flutter/material.dart';

class QuestionProgressBar extends StatelessWidget {
  final int currentQuestion;
  final int totalQuestions;
  final List<bool> answeredCorrectly;

  const QuestionProgressBar({
    Key? key,
    required this.currentQuestion,
    required this.totalQuestions,
    required this.answeredCorrectly,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[800],
      ),
      child: Row(
        children: List.generate(totalQuestions, (index) {
          bool isAnswered = index < answeredCorrectly.length;
          bool isCorrect = isAnswered ? answeredCorrectly[index] : false;
          bool isCurrent = index == currentQuestion - 1;

          Color segmentColor;
          if (isAnswered) {
            segmentColor = isCorrect ? Colors.green : Colors.orange;
          } else if (isCurrent) {
            segmentColor = Colors.blue;
          } else {
            segmentColor = Colors.transparent;
          }

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: segmentColor,
              ),
            ),
          );
        }),
      ),
    );
  }
}
