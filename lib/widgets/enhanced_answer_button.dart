// lib/widgets/enhanced_answer_button.dart
import 'package:flutter/material.dart';

class EnhancedAnswerButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final bool isDisabled;

  const EnhancedAnswerButton({
    Key? key,
    required this.text,
    required this.onTap,
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.isDisabled = false,
  }) : super(key: key);

  @override
  State<EnhancedAnswerButton> createState() => _EnhancedAnswerButtonState();
}

class _EnhancedAnswerButtonState extends State<EnhancedAnswerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isDisabled) {
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isDisabled) {
      _controller.reverse();
    }
  }

  void _handleTapCancel() {
    if (!widget.isDisabled) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if this is a correct/incorrect answer based on color
    final bool isCorrect = widget.backgroundColor == Colors.green;
    final bool isIncorrect = widget.backgroundColor == Colors.red;
    final bool isAnswered = isCorrect || isIncorrect;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAnswered
                      ? (isCorrect ? Colors.green : Colors.red)
                      : Colors.white.withOpacity(0.2),
                  width: isAnswered ? 3 : 2,
                ),
                boxShadow: widget.isDisabled
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isAnswered
                      ? (isCorrect
                          ? [Colors.green.shade600, Colors.green.shade800]
                          : [Colors.red.shade600, Colors.red.shade800])
                      : [
                          widget.backgroundColor,
                          widget.backgroundColor.withOpacity(0.8),
                        ],
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Material(
                  color: Colors.transparent,
                  elevation: 0,
                  child: InkWell(
                    onTap: widget.isDisabled ? null : widget.onTap,
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    splashColor: Colors.white.withOpacity(0.2),
                    highlightColor: Colors.white.withOpacity(0.1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isAnswered) ...[
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              widget.text,
                              style: TextStyle(
                                color: widget.textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
