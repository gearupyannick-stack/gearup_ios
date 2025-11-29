import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/race_challenge.dart';
import '../../services/chat_service.dart';
import '../../widgets/race_challenge_card.dart';
import '../race_page.dart';

class RaceChallengeDetailPage extends StatefulWidget {
  final String clubId;
  final String challengeId;

  const RaceChallengeDetailPage({
    Key? key,
    required this.clubId,
    required this.challengeId,
  }) : super(key: key);

  @override
  State<RaceChallengeDetailPage> createState() => _RaceChallengeDetailPageState();
}

class _RaceChallengeDetailPageState extends State<RaceChallengeDetailPage> {
  final _user = FirebaseAuth.instance.currentUser;
  RaceChallenge? _currentChallenge;

  Future<void> _joinChallenge() async {
    try {
      await ChatService.instance.joinRaceChallenge(
        widget.clubId,
        widget.challengeId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Joined the race!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _leaveChallenge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Race'),
        content: const Text('Are you sure you want to leave this race challenge?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ChatService.instance.leaveRaceChallenge(
          widget.clubId,
          widget.challengeId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Left the race'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to leave: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _startChallenge() async {
    try {
      final roomCode = await ChatService.instance.startRaceChallenge(
        widget.clubId,
        widget.challengeId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Race starting!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to race page with room code
        _enterRace(roomCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _enterRace(String roomCode) {
    if (_currentChallenge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Challenge data not loaded'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to RacePage with club race parameters
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RacePage(
          clubRaceRoomCode: roomCode,
          clubId: widget.clubId,
          challengeId: widget.challengeId,
          clubRaceQuestions: _currentChallenge!.questionsCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Race Challenge'),
        backgroundColor: const Color(0xFF3D0000),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<RaceChallenge>(
        stream: ChatService.instance.getRaceChallengeStream(
          widget.clubId,
          widget.challengeId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading challenge',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: Text('Challenge not found'),
            );
          }

          final challenge = snapshot.data!;
          _currentChallenge = challenge; // Store current challenge for navigation
          final isParticipant = _user != null && challenge.isParticipant(_user.uid);
          final isCreator = _user != null && challenge.creatorId == _user.uid;

          return SingleChildScrollView(
            child: Column(
              children: [
                RaceChallengeCard(
                  challenge: challenge,
                  isParticipant: isParticipant,
                  isCreator: isCreator,
                  onJoinPressed: _joinChallenge,
                  onLeavePressed: _leaveChallenge,
                  onStartPressed: _startChallenge,
                  onEnterRacePressed: () {
                    if (challenge.roomCode != null) {
                      _enterRace(challenge.roomCode!);
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildInstructions(challenge),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInstructions(RaceChallenge challenge) {
    String instructions;

    if (challenge.isActive) {
      instructions = 'The race is active! Join the room with code: ${challenge.roomCode}';
    } else if (challenge.isCompleted) {
      instructions = 'This race has been completed.';
    } else if (challenge.isCancelled) {
      instructions = 'This race was cancelled.';
    } else if (challenge.isInstant) {
      instructions = 'This race will start automatically when ${challenge.maxParticipants} players join.';
    } else {
      instructions = 'This race is scheduled to start at ${DateFormat('MMM d, yyyy - HH:mm').format(challenge.scheduledTime!)}.';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instructions,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
