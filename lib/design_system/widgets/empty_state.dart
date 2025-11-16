import 'package:flutter/material.dart';
import '../tokens.dart';

/// Empty state widget for displaying error, no data, or placeholder states
/// Provides consistent UX for edge cases
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Widget? customIcon;
  final bool showAnimation;

  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.customIcon,
    this.showAnimation = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: DesignTokens.paddingLarge,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon or custom widget
            if (showAnimation)
              _AnimatedIcon(
                icon: customIcon ??
                    Icon(
                      icon ?? Icons.info_outline,
                      size: DesignTokens.iconSizeXLarge * 2,
                      color: iconColor ?? DesignTokens.textTertiary,
                    ),
              )
            else if (customIcon != null)
              customIcon!
            else
              Icon(
                icon ?? Icons.info_outline,
                size: DesignTokens.iconSizeXLarge * 2,
                color: iconColor ?? DesignTokens.textTertiary,
              ),

            const SizedBox(height: DesignTokens.space24),

            // Title
            Text(
              title,
              style: DesignTokens.heading3.copyWith(
                color: DesignTokens.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtitle
            if (subtitle != null) ...[
              const SizedBox(height: DesignTokens.space12),
              Text(
                subtitle!,
                style: DesignTokens.bodyMedium.copyWith(
                  color: DesignTokens.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: DesignTokens.space24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pre-configured error state
  factory EmptyState.error({
    String? title,
    String? subtitle,
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.error_outline,
      iconColor: DesignTokens.error,
      title: title ?? 'Something went wrong',
      subtitle: subtitle ?? 'Please try again later',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Pre-configured network error state
  factory EmptyState.networkError({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.wifi_off,
      iconColor: DesignTokens.warning,
      title: 'No internet connection',
      subtitle: 'Please check your connection and try again',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
    );
  }

  /// Pre-configured no data state
  factory EmptyState.noData({
    String? title,
    String? subtitle,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    return EmptyState(
      icon: Icons.inbox_outlined,
      iconColor: DesignTokens.textTertiary,
      title: title ?? 'No data available',
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Pre-configured image load error
  factory EmptyState.imageError({
    VoidCallback? onRetry,
  }) {
    return EmptyState(
      icon: Icons.broken_image_outlined,
      iconColor: DesignTokens.textTertiary,
      title: 'Failed to load image',
      subtitle: 'The image could not be loaded',
      actionLabel: onRetry != null ? 'Retry' : null,
      onAction: onRetry,
      showAnimation: false,
    );
  }

  /// Pre-configured search no results
  factory EmptyState.noResults({
    String? searchQuery,
  }) {
    return EmptyState(
      icon: Icons.search_off,
      iconColor: DesignTokens.textTertiary,
      title: 'No results found',
      subtitle: searchQuery != null
          ? 'No results for "$searchQuery"'
          : 'Try a different search term',
    );
  }

  /// Pre-configured race not found
  factory EmptyState.raceNotFound({
    VoidCallback? onBackToLobby,
  }) {
    return EmptyState(
      icon: Icons.not_interested,
      iconColor: DesignTokens.warning,
      title: 'Race not found',
      subtitle: 'This race may have already started or been cancelled',
      actionLabel: onBackToLobby != null ? 'Back to Lobby' : null,
      onAction: onBackToLobby,
    );
  }

  /// Pre-configured waiting for players
  factory EmptyState.waitingForPlayers({
    int currentPlayers = 0,
    int requiredPlayers = 2,
  }) {
    return EmptyState(
      customIcon: const _WaitingAnimation(),
      title: 'Waiting for players...',
      subtitle: '$currentPlayers / $requiredPlayers players ready',
      showAnimation: true,
    );
  }

  /// Pre-configured maintenance mode
  factory EmptyState.maintenance() {
    return const EmptyState(
      icon: Icons.build_outlined,
      iconColor: DesignTokens.warning,
      title: 'Under maintenance',
      subtitle: 'We\'ll be back soon! Thanks for your patience.',
      showAnimation: true,
    );
  }
}

/// Animated icon wrapper with subtle bounce
class _AnimatedIcon extends StatefulWidget {
  final Widget icon;

  const _AnimatedIcon({required this.icon});

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.icon,
    );
  }
}

/// Waiting animation (pulsing circles)
class _WaitingAnimation extends StatefulWidget {
  const _WaitingAnimation();

  @override
  State<_WaitingAnimation> createState() => _WaitingAnimationState();
}

class _WaitingAnimationState extends State<_WaitingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.3;
              final progress = (_controller.value - delay) % 1.0;

              return Container(
                width: 20 + (progress * 60),
                height: 20 + (progress * 60),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DesignTokens.primaryRed.withOpacity(1.0 - progress),
                    width: 3,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Error card widget for inline errors
class ErrorCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onRetry;
  final IconData icon;
  final Color? backgroundColor;
  final Color? iconColor;

  const ErrorCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onRetry,
    this.icon = Icons.error_outline,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        color: backgroundColor ?? DesignTokens.error.withOpacity(0.1),
        borderRadius: DesignTokens.borderRadiusMedium,
        border: Border.all(
          color: (iconColor ?? DesignTokens.error).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? DesignTokens.error,
            size: DesignTokens.iconSizeMedium,
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DesignTokens.bodyMedium.copyWith(
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    subtitle!,
                    style: DesignTokens.bodySmall.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: DesignTokens.space12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Success card widget for positive feedback
class SuccessCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;
  final bool autoDismiss;

  const SuccessCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
    this.autoDismiss = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        color: DesignTokens.success.withOpacity(0.1),
        borderRadius: DesignTokens.borderRadiusMedium,
        border: Border.all(
          color: DesignTokens.success.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: DesignTokens.success,
            size: DesignTokens.iconSizeMedium,
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DesignTokens.bodyMedium.copyWith(
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    subtitle!,
                    style: DesignTokens.bodySmall.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: DesignTokens.space12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Warning card widget
class WarningCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const WarningCard({
    super.key,
    required this.title,
    this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DesignTokens.paddingMedium,
      decoration: BoxDecoration(
        color: DesignTokens.warning.withOpacity(0.1),
        borderRadius: DesignTokens.borderRadiusMedium,
        border: Border.all(
          color: DesignTokens.warning.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber,
            color: DesignTokens.warning,
            size: DesignTokens.iconSizeMedium,
          ),
          const SizedBox(width: DesignTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: DesignTokens.bodyMedium.copyWith(
                    fontWeight: DesignTokens.weightSemiBold,
                    color: DesignTokens.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DesignTokens.space4),
                  Text(
                    subtitle!,
                    style: DesignTokens.bodySmall.copyWith(
                      color: DesignTokens.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(width: DesignTokens.space12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
