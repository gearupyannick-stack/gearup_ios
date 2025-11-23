import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

/// A reusable tutorial overlay that appears over existing content
/// to explain features during the interactive tutorial.
///
/// This overlay:
/// - Appears AFTER user has opened a dialog/page
/// - Shows explanation text while content is visible
/// - Has a Continue button to progress tutorial
/// - Semi-transparent background to focus attention
class TutorialOverlay extends StatelessWidget {
  /// The tutorial text to display (translation key)
  final String textKey;

  /// Optional additional text (translation key) shown below main text
  final String? subtextKey;

  /// Callback when Continue button is tapped
  final VoidCallback onContinue;

  /// Whether to show the Continue button (true by default)
  final bool showContinueButton;

  /// Optional custom Continue button text (defaults to "tutorial.continue")
  final String? continueButtonTextKey;

  const TutorialOverlay({
    Key? key,
    required this.textKey,
    this.subtextKey,
    required this.onContinue,
    this.showContinueButton = true,
    this.continueButtonTextKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            // Main content area
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: size.width * 0.1,
                  vertical: size.height * 0.15,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE53935).withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main tutorial text
                    Text(
                      textKey.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),

                    // Optional subtext
                    if (subtextKey != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        subtextKey!.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // Continue button
                    if (showContinueButton) ...[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                          ),
                          child: Text(
                            (continueButtonTextKey ?? 'tutorial.continue').tr(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simpler tutorial overlay that just shows text without a button
/// Used when waiting for user to tap a highlighted element
class TutorialPrompt extends StatelessWidget {
  /// The prompt text to display (translation key)
  final String textKey;

  const TutorialPrompt({
    Key? key,
    required this.textKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Positioned(
      top: size.height * 0.5 - 50,
      left: size.width * 0.1,
      right: size.width * 0.1,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          textKey.tr(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
