import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../tokens.dart';

/// Professional race join dialog with elegant design and loading states
/// Replaces the basic AlertDialog implementations
class RaceJoinDialog extends StatefulWidget {
  final String trackName;
  final String? trackImagePath;
  final int questionCount;
  final String description;
  final String initialPlayerName;
  final VoidCallback? onJoin;
  final Future<bool> Function(String playerName)? onJoinAsync;
  final VoidCallback? onCancel;
  final bool showDifficulty;

  const RaceJoinDialog({
    super.key,
    required this.trackName,
    this.trackImagePath,
    required this.questionCount,
    required this.description,
    required this.initialPlayerName,
    this.onJoin,
    this.onJoinAsync,
    this.onCancel,
    this.showDifficulty = true,
  });

  @override
  State<RaceJoinDialog> createState() => _RaceJoinDialogState();

  /// Static method to show the dialog
  static Future<bool?> show(
    BuildContext context, {
    required String trackName,
    String? trackImagePath,
    required int questionCount,
    required String description,
    required String initialPlayerName,
    VoidCallback? onJoin,
    Future<bool> Function(String playerName)? onJoinAsync,
    bool showDifficulty = true,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RaceJoinDialog(
        trackName: trackName,
        trackImagePath: trackImagePath,
        questionCount: questionCount,
        description: description,
        initialPlayerName: initialPlayerName,
        onJoin: onJoin,
        onJoinAsync: onJoinAsync,
        showDifficulty: showDifficulty,
      ),
    );
  }
}

class _RaceJoinDialogState extends State<RaceJoinDialog>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  bool _showDetailedInfo = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialPlayerName);

    _animationController = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignTokens.curveEmphasized,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: DesignTokens.curveDefault,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'race.pleaseEnterName'.tr();
      });
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.onJoinAsync != null) {
        final success = await widget.onJoinAsync!(_nameController.text.trim());
        if (mounted && success) {
          Navigator.of(context).pop(true);
        } else if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'race.failedToJoinRace'.tr();
          });
        }
      } else {
        widget.onJoin?.call();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'common.errorOccurred'.tr();
        });
      }
    }
  }

  void _handleCancel() {
    widget.onCancel?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space24,
            vertical: DesignTokens.space24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2D2D2D),
                  Color(0xFF1E1E1E),
                ],
              ),
              borderRadius: DesignTokens.borderRadiusXLarge,
              boxShadow: DesignTokens.shadowLevel4,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Track preview image (optional)
                if (widget.trackImagePath != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(DesignTokens.radiusXLarge),
                    ),
                    child: Image.asset(
                      widget.trackImagePath!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: DesignTokens.surfaceHighlighted,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: DesignTokens.textTertiary,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(DesignTokens.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Track name
                      Text(
                        widget.trackName,
                        style: DesignTokens.heading2.copyWith(
                          color: DesignTokens.white,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: DesignTokens.space8),

                      // Question count badge
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DesignTokens.space16,
                            vertical: DesignTokens.space8,
                          ),
                          decoration: BoxDecoration(
                            color: DesignTokens.primaryRed.withOpacity(0.2),
                            borderRadius: DesignTokens.borderRadiusFull,
                            border: Border.all(
                              color: DesignTokens.primaryRed.withOpacity(0.5),
                            ),
                          ),
                          child: Text(
                            'race.questionCount'.tr(namedArgs: {'count': widget.questionCount.toString()}),
                            style: DesignTokens.bodySmall.copyWith(
                              color: DesignTokens.primaryRed,
                              fontWeight: DesignTokens.weightBold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: DesignTokens.space20),

                      // Compact description with expandable details
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.description.split('.').first + '.', // First sentence only
                              style: DesignTokens.bodyMedium.copyWith(
                                color: DesignTokens.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _showDetailedInfo ? Icons.info : Icons.info_outline,
                              color: DesignTokens.info,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _showDetailedInfo = !_showDetailedInfo);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'common.moreInfo'.tr(),
                          ),
                        ],
                      ),

                      // Expandable detailed info
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: DesignTokens.space12),
                            Container(
                              padding: const EdgeInsets.all(DesignTokens.space12),
                              decoration: BoxDecoration(
                                color: DesignTokens.info.withOpacity(0.1),
                                borderRadius: DesignTokens.borderRadiusSmall,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.description.split('.').length > 1)
                                    Text(
                                      widget.description.split('.').skip(1).join('.').trim(),
                                      style: DesignTokens.bodySmall.copyWith(
                                        color: DesignTokens.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  if (widget.showDifficulty) ...[
                                    const SizedBox(height: DesignTokens.space8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.trending_up,
                                          size: 16,
                                          color: DesignTokens.info,
                                        ),
                                        const SizedBox(width: DesignTokens.space8),
                                        Expanded(
                                          child: Text(
                                            'race.difficultyProgression'.tr(),
                                            style: DesignTokens.bodySmall.copyWith(
                                              color: DesignTokens.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        crossFadeState: _showDetailedInfo
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: DesignTokens.durationMedium,
                      ),

                      const SizedBox(height: DesignTokens.space24),

                      // Player name input
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose your player name:',
                            style: DesignTokens.bodyMedium.copyWith(
                              color: DesignTokens.textPrimary,
                              fontWeight: DesignTokens.weightSemiBold,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.space8),
                          TextField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            autofocus: true,
                            maxLength: 20,
                            style: DesignTokens.bodyLarge.copyWith(
                              color: DesignTokens.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: TextStyle(
                                color: DesignTokens.textTertiary,
                              ),
                              filled: true,
                              fillColor: DesignTokens.surfaceHighlighted,
                              border: OutlineInputBorder(
                                borderRadius: DesignTokens.borderRadiusMedium,
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: DesignTokens.borderRadiusMedium,
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: DesignTokens.borderRadiusMedium,
                                borderSide: const BorderSide(
                                  color: DesignTokens.primaryRed,
                                  width: 2,
                                ),
                              ),
                              counterStyle: DesignTokens.caption.copyWith(
                                color: DesignTokens.textTertiary,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: DesignTokens.textSecondary,
                              ),
                            ),
                            onSubmitted: (_) => _handleJoin(),
                          ),
                        ],
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        const SizedBox(height: DesignTokens.space12),
                        Container(
                          padding: const EdgeInsets.all(DesignTokens.space12),
                          decoration: BoxDecoration(
                            color: DesignTokens.error.withOpacity(0.1),
                            borderRadius: DesignTokens.borderRadiusSmall,
                            border: Border.all(
                              color: DesignTokens.error.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 16,
                                color: DesignTokens.error,
                              ),
                              const SizedBox(width: DesignTokens.space8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: DesignTokens.bodySmall.copyWith(
                                    color: DesignTokens.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: DesignTokens.space24),

                      // Buttons
                      Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _handleCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: DesignTokens.textSecondary,
                                side: BorderSide(
                                  color: DesignTokens.textTertiary.withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: DesignTokens.space16,
                                ),
                              ),
                              child: Text('common.cancel'.tr()),
                            ),
                          ),

                          const SizedBox(width: DesignTokens.space12),

                          // Join button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleJoin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DesignTokens.primaryRed,
                                foregroundColor: DesignTokens.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: DesignTokens.space16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: DesignTokens.borderRadiusMedium,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          DesignTokens.white,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text('race.joinRace'.tr()),
                                        const SizedBox(width: DesignTokens.space8),
                                        const Icon(Icons.arrow_forward, size: 18),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
