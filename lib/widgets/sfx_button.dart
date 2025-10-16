// lib/widgets/sfx_button.dart
import 'package:flutter/material.dart';
import '../services/audio_feedback.dart';

/// SfxButton: wraps an area with tap sound via AudioFeedback before calling onPressed.
///
/// Usage:
///  - SfxButton.elevated(child: Text('Start'), onPressed: _start)
///  - SfxButton(child: Icon(Icons.edit), onPressed: _open)
class SfxButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final double? splashRadius;

  const SfxButton({
    Key? key,
    required this.child,
    required this.onPressed,
    this.enabled = true,
    this.padding,
    this.splashRadius,
  }) : super(key: key);

  factory SfxButton.elevated({
    Key? key,
    required Widget child,
    required VoidCallback? onPressed,
    EdgeInsetsGeometry? padding,
  }) {
    return SfxButton(
      key: key,
      child: child,
      onPressed: onPressed,
      padding: padding,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cb = enabled ? onPressed : null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: cb == null ? null : () {
        // centralized tap event
        try {
          AudioFeedback.instance.playEvent(SoundEvent.tap);
        } catch (_) {
          // be safe if audio not ready
        }
        cb();
      },
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Center(child: child),
      ),
      splashColor: Theme.of(context).splashColor.withOpacity(0.12),
      highlightColor: Colors.transparent,
      radius: splashRadius ?? 24,
    );
  }
}