import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/race_leaderboard_entry.dart';
import '../services/leaderboard_service.dart';

/// Widget displaying the competitive race leaderboard
class LeaderboardWidget extends StatefulWidget {
  const LeaderboardWidget({Key? key}) : super(key: key);

  @override
  State<LeaderboardWidget> createState() => _LeaderboardWidgetState();
}

class _LeaderboardWidgetState extends State<LeaderboardWidget> {
  final LeaderboardService _leaderboardService = LeaderboardService();
  RaceLeaderboardEntry? _currentUserEntry;
  int? _currentUserRank;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final entry = await _leaderboardService.getPlayerEntry(userId);
      final rank = await _leaderboardService.getPlayerRank(userId);
      if (mounted) {
        setState(() {
          _currentUserEntry = entry;
          _currentUserRank = rank;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade900,
            Colors.black,
          ],
        ),
      ),
      child: RefreshIndicator(
        onRefresh: _loadCurrentUserData,
        child: StreamBuilder<List<RaceLeaderboardEntry>>(
          stream: _leaderboardService.getTopPlayersStream(limit: 10),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading leaderboard',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loadCurrentUserData,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final topPlayers = snapshot.data ?? [];

            if (topPlayers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                         color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'No rankings yet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to compete in 1v1 races!',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      'Global Leaderboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Top 10 Competitive Racers',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Top 10 List
                ...topPlayers.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final player = entry.value;
                  final isCurrentUser = player.userId ==
                      FirebaseAuth.instance.currentUser?.uid;

                  return _buildPlayerRow(
                    rank: rank,
                    player: player,
                    isCurrentUser: isCurrentUser,
                    isTopThree: rank <= 3,
                  );
                }).toList(),

                // Current user section (if not in top 10)
                if (_currentUserEntry != null &&
                    _currentUserRank != null &&
                    _currentUserRank! > 10) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.white30, thickness: 2),
                  const SizedBox(height: 16),
                  _buildPlayerRow(
                    rank: _currentUserRank!,
                    player: _currentUserEntry!,
                    isCurrentUser: true,
                    isTopThree: false,
                  ),
                ],

                // Bottom spacing
                const SizedBox(height: 80),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerRow({
    required int rank,
    required RaceLeaderboardEntry player,
    required bool isCurrentUser,
    required bool isTopThree,
  }) {
    Color backgroundColor = isCurrentUser
        ? Colors.blue.withOpacity(0.3)
        : Colors.white.withOpacity(0.05);

    if (isTopThree && !isCurrentUser) {
      backgroundColor = rank == 1
          ? Colors.amber.withOpacity(0.2)
          : rank == 2
              ? Colors.grey.withOpacity(0.2)
              : Colors.brown.withOpacity(0.2);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: Colors.blue, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank badge
          _buildRankBadge(rank, isTopThree),
          const SizedBox(width: 12),

          // Country flag
          Text(
            _getCountryFlag(player.country),
            style: TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  player.recordString,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // ELO rating
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${player.eloRating}',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank, bool isTopThree) {
    if (isTopThree) {
      Color badgeColor = rank == 1
          ? Colors.amber
          : rank == 2
              ? Colors.grey.shade300
              : Colors.brown.shade300;

      IconData icon = rank == 1
          ? Icons.emoji_events
          : rank == 2
              ? Icons.military_tech
              : Icons.workspace_premium;

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: badgeColor.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: badgeColor, width: 2),
        ),
        child: Icon(icon, color: badgeColor, size: 24),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$rank',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getCountryFlag(String countryCode) {
    if (countryCode == 'XX' || countryCode.length != 2) {
      return '🏁'; // Default flag for unknown country
    }

    // Convert ISO country code to flag emoji
    // Each country code letter maps to a regional indicator symbol
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;

    return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
  }
}
