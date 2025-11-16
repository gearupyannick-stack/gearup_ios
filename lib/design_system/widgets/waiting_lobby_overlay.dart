import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens.dart';
import '../../services/collab_wan_service.dart';

/// Professional waiting lobby overlay with player list, room code, and progress
/// Replaces basic black container overlays
class WaitingLobbyOverlay extends StatefulWidget {
  final String? roomCode;
  final List<PlayerInfo> players;
  final int requiredPlayers;
  final int totalQuestions;
  final String waitingMessage;
  final bool showRoomCode;
  final bool showStartButton;
  final VoidCallback? onStartRace;
  final VoidCallback? onLeave;

  const WaitingLobbyOverlay({
    super.key,
    this.roomCode,
    required this.players,
    this.requiredPlayers = 2,
    this.totalQuestions = 12,
    required this.waitingMessage,
    this.showRoomCode = false,
    this.showStartButton = false,
    this.onStartRace,
    this.onLeave,
  });

  @override
  State<WaitingLobbyOverlay> createState() => _WaitingLobbyOverlayState();
}

class _WaitingLobbyOverlayState extends State<WaitingLobbyOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _codeCopied = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: DesignTokens.durationMedium,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _copyRoomCode() async {
    if (widget.roomCode == null) return;

    await Clipboard.setData(ClipboardData(text: widget.roomCode!));
    HapticFeedback.mediumImpact();

    setState(() => _codeCopied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _codeCopied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Stack(
        children: [
          // Blurred backdrop
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: DesignTokens.black.withOpacity(0.7),
              ),
            ),
          ),

          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.space24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Compact waiting message at top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Small player count indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DesignTokens.space12,
                          vertical: DesignTokens.space8,
                        ),
                        decoration: BoxDecoration(
                          color: DesignTokens.primaryRed.withOpacity(0.2),
                          borderRadius: DesignTokens.borderRadiusSmall,
                          border: Border.all(
                            color: DesignTokens.primaryRed.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${widget.players.length}/${widget.requiredPlayers}',
                          style: DesignTokens.bodyMedium.copyWith(
                            color: DesignTokens.primaryRed,
                            fontWeight: DesignTokens.weightBold,
                          ),
                        ),
                      ),
                      const SizedBox(width: DesignTokens.space12),
                      // Waiting message
                      Text(
                        widget.waitingMessage,
                        style: DesignTokens.heading3.copyWith(
                          color: DesignTokens.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: DesignTokens.space16),

                  // Small subtitle
                  Text(
                    '${widget.totalQuestions} questions await',
                    style: DesignTokens.caption.copyWith(
                      color: DesignTokens.textTertiary,
                    ),
                  ),

                  const SizedBox(height: DesignTokens.space24),

                  // Room code card (if showing) - now in center position
                  if (widget.showRoomCode && widget.roomCode != null) ...[
                    _RoomCodeCard(
                      roomCode: widget.roomCode!,
                      onCopy: _copyRoomCode,
                      copied: _codeCopied,
                    ),
                    const SizedBox(height: DesignTokens.space24),
                  ],

                  // Player list
                  ...widget.players.asMap().entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: DesignTokens.space12),
                      child: _PlayerCard(
                        player: entry.value,
                        index: entry.key,
                      ),
                    );
                  }).toList(),

                  // Start race button (if creator and ready)
                  if (widget.showStartButton && widget.onStartRace != null) ...[
                    const SizedBox(height: DesignTokens.space24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onStartRace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DesignTokens.primaryRedDark,
                          foregroundColor: DesignTokens.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: DesignTokens.space16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: DesignTokens.borderRadiusMedium,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_arrow, size: 24),
                            SizedBox(width: DesignTokens.space8),
                            Text('Start Race', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Leave button
                  if (widget.onLeave != null) ...[
                    const SizedBox(height: DesignTokens.space12),
                    TextButton(
                      onPressed: widget.onLeave,
                      child: Text(
                        'Leave Lobby',
                        style: TextStyle(color: DesignTokens.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Room code card with copy functionality
class _RoomCodeCard extends StatelessWidget {
  final String roomCode;
  final VoidCallback onCopy;
  final bool copied;

  const _RoomCodeCard({
    required this.roomCode,
    required this.onCopy,
    required this.copied,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.space20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF3D3D3D),
            Color(0xFF2D2D2D),
          ],
        ),
        borderRadius: DesignTokens.borderRadiusLarge,
        border: Border.all(
          color: DesignTokens.primaryRed.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: DesignTokens.shadowLevel2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Room Code',
            style: DesignTokens.bodyMedium.copyWith(
              color: DesignTokens.textSecondary,
              fontWeight: DesignTokens.weightMedium,
            ),
          ),
          const SizedBox(height: DesignTokens.space12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    roomCode.toUpperCase(),
                    style: DesignTokens.displayLarge.copyWith(
                      color: DesignTokens.primaryRed,
                      fontWeight: DesignTokens.weightBold,
                      letterSpacing: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.space16),
              InkWell(
                onTap: onCopy,
                borderRadius: DesignTokens.borderRadiusFull,
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.space8),
                  decoration: BoxDecoration(
                    color: copied
                        ? DesignTokens.success
                        : DesignTokens.surfaceHighlighted,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    copied ? Icons.check : Icons.copy,
                    size: 20,
                    color: DesignTokens.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.space8),
          Text(
            'Share this code with friends!',
            style: DesignTokens.caption.copyWith(
              color: DesignTokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Player card with avatar and status
class _PlayerCard extends StatelessWidget {
  final PlayerInfo player;
  final int index;

  const _PlayerCard({
    required this.player,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOutBack,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.space16),
        decoration: BoxDecoration(
          color: DesignTokens.surfaceElevated,
          borderRadius: DesignTokens.borderRadiusMedium,
          border: Border.all(
            color: DesignTokens.primaryRed.withOpacity(0.2),
          ),
          boxShadow: DesignTokens.shadowLevel1,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: DesignTokens.primaryRed,
                  child: Text(
                    player.displayName.isNotEmpty
                        ? player.displayName[0].toUpperCase()
                        : '?',
                    style: DesignTokens.heading3.copyWith(
                      color: DesignTokens.white,
                    ),
                  ),
                ),
                // Ready indicator
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _PulsingDot(color: DesignTokens.success),
                ),
              ],
            ),

            const SizedBox(width: DesignTokens.space12),

            // Player name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.displayName,
                    style: DesignTokens.bodyLarge.copyWith(
                      color: DesignTokens.textPrimary,
                      fontWeight: DesignTokens.weightSemiBold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready',
                    style: DesignTokens.caption.copyWith(
                      color: DesignTokens.success,
                    ),
                  ),
                ],
              ),
            ),

            // Connection indicator
            Icon(
              Icons.signal_cellular_alt,
              size: 20,
              color: DesignTokens.success.withOpacity(0.7),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated waiting text with dots
class _AnimatedWaitingText extends StatefulWidget {
  final String message;

  const _AnimatedWaitingText({required this.message});

  @override
  State<_AnimatedWaitingText> createState() => _AnimatedWaitingTextState();
}

class _AnimatedWaitingTextState extends State<_AnimatedWaitingText> {
  late Stream<int> _dotStream;

  @override
  void initState() {
    super.initState();
    _dotStream = Stream.periodic(
      const Duration(milliseconds: 500),
      (count) => count % 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _dotStream,
      builder: (context, snapshot) {
        final dots = '.' * (snapshot.data ?? 0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.message,
              style: DesignTokens.heading3.copyWith(
                color: DesignTokens.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              width: 24, // Fixed width for 3 dots
              child: Text(
                dots,
                style: DesignTokens.heading3.copyWith(
                  color: DesignTokens.textPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pulsing dot indicator
class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({
    required this.color,
  });

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: DesignTokens.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

// PlayerInfo class removed - use the one from collab_wan_service.dart instead
