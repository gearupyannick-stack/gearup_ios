import 'dart:async';
import 'package:flutter/material.dart';
import '../models/race_challenge.dart';

class RaceChallengeCard extends StatefulWidget {
  final RaceChallenge challenge;
  final bool isParticipant;
  final bool isCreator;
  final VoidCallback? onJoinPressed;
  final VoidCallback? onLeavePressed;
  final VoidCallback? onStartPressed;
  final VoidCallback? onEnterRacePressed;

  const RaceChallengeCard({
    Key? key,
    required this.challenge,
    required this.isParticipant,
    required this.isCreator,
    this.onJoinPressed,
    this.onLeavePressed,
    this.onStartPressed,
    this.onEnterRacePressed,
  }) : super(key: key);

  @override
  State<RaceChallengeCard> createState() => _RaceChallengeCardState();
}

class _RaceChallengeCardState extends State<RaceChallengeCard> {
  Timer? _countdownTimer;
  Duration? _timeRemaining;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (widget.challenge.isScheduled && widget.challenge.scheduledTime != null) {
      _updateTimeRemaining();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateTimeRemaining();
      });
    }
  }

  void _updateTimeRemaining() {
    if (widget.challenge.scheduledTime == null) return;

    final remaining = widget.challenge.scheduledTime!.difference(DateTime.now());
    if (mounted) {
      setState(() {
        _timeRemaining = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getBorderColor(),
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDetails(),
            const SizedBox(height: 16),
            _buildParticipants(),
            if (widget.challenge.isScheduled && _timeRemaining != null) ...[
              const SizedBox(height: 16),
              _buildCountdown(),
            ],
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (widget.challenge.isActive) {
      return Colors.green.shade50;
    } else if (widget.challenge.isCompleted) {
      return Colors.grey.shade100;
    } else if (widget.challenge.isCancelled) {
      return Colors.grey.shade100;
    } else {
      return Colors.red.shade50;
    }
  }

  Color _getBorderColor() {
    if (widget.challenge.isActive) {
      return Colors.green.shade400;
    } else if (widget.challenge.isCompleted) {
      return Colors.grey.shade400;
    } else if (widget.challenge.isCancelled) {
      return Colors.grey.shade400;
    } else {
      return Colors.red.shade400;
    }
  }

  Widget _buildHeader() {
    final accentColor = _getAccentColor();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 2),
          ),
          child: Icon(
            widget.challenge.isInstant ? Icons.flash_on : Icons.schedule,
            color: accentColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.challenge.isInstant ? 'Instant Race' : 'Scheduled Race',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              Text(
                'by ${widget.challenge.creatorDisplayName}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Color _getAccentColor() {
    if (widget.challenge.isActive) {
      return Colors.green.shade700;
    } else if (widget.challenge.isCompleted) {
      return Colors.grey.shade700;
    } else if (widget.challenge.isCancelled) {
      return Colors.grey.shade700;
    } else {
      return const Color(0xFFE53935);
    }
  }

  Widget _buildStatusBadge() {
    String status;
    Color bgColor;
    Color textColor;

    if (widget.challenge.isActive) {
      status = 'Active';
      bgColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
    } else if (widget.challenge.isCompleted) {
      status = 'Completed';
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    } else if (widget.challenge.isCancelled) {
      status = 'Cancelled';
      bgColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    } else {
      status = 'Open';
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final accentColor = _getAccentColor();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildDetailItem(
            Icons.question_answer,
            '${widget.challenge.questionsCount} Questions',
            accentColor,
          ),
          Container(
            width: 1,
            height: 30,
            color: accentColor.withOpacity(0.3),
          ),
          _buildDetailItem(
            Icons.people,
            '${widget.challenge.participantIds.length}/${widget.challenge.maxParticipants}',
            accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildParticipants() {
    final accentColor = _getAccentColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Participants',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...List.generate(
              widget.challenge.participantIds.length,
              (index) => _buildParticipantAvatar(index, accentColor),
            ),
            if (!widget.challenge.isFull && widget.challenge.isOpen)
              _buildEmptySlot(accentColor),
          ],
        ),
      ],
    );
  }

  Widget _buildParticipantAvatar(int index, Color accentColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: accentColor,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySlot(Color accentColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Icon(
        Icons.add,
        color: Colors.grey.shade600,
        size: 20,
      ),
    );
  }

  Widget _buildCountdown() {
    if (_timeRemaining == null) return const SizedBox.shrink();

    final hours = _timeRemaining!.inHours;
    final minutes = _timeRemaining!.inMinutes % 60;
    final seconds = _timeRemaining!.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            hours > 0
                ? '${hours}h ${minutes}m ${seconds}s'
                : '${minutes}m ${seconds}s',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    if (widget.challenge.isCompleted || widget.challenge.isCancelled) {
      return const SizedBox.shrink();
    }

    if (widget.challenge.isActive) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onEnterRacePressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text(
            'Enter Race',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (widget.isParticipant) {
      return Row(
        children: [
          if (widget.isCreator && widget.challenge.participantIds.length >= 2)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onStartPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text(
                  'Start Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (widget.isCreator && widget.challenge.participantIds.length >= 2)
            const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onLeavePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade700, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Leave',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.challenge.isFull ? null : widget.onJoinPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade600,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.add),
          label: Text(
            widget.challenge.isFull ? 'Full' : 'Join Race',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
  }
}
