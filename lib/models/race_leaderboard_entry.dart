import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a player's entry in the competitive race leaderboard
class RaceLeaderboardEntry {
  final String userId;
  final String displayName;
  final String country; // ISO country code (e.g., 'US', 'FR', 'JP')
  final int eloRating;
  final int wins;
  final int losses;
  final int totalRaces;
  final DateTime? lastRaceAt;
  final DateTime createdAt;

  RaceLeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.country,
    required this.eloRating,
    required this.wins,
    required this.losses,
    required this.totalRaces,
    this.lastRaceAt,
    required this.createdAt,
  });

  /// Win rate as a percentage (0-100)
  double get winRate {
    if (totalRaces == 0) return 0.0;
    return (wins / totalRaces) * 100;
  }

  /// Win-Loss record as a string (e.g., "10-5")
  String get recordString => '$wins-$losses';

  /// Factory constructor from Firestore document
  factory RaceLeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceLeaderboardEntry(
      userId: doc.id,
      displayName: data['displayName'] ?? 'Unknown',
      country: data['country'] ?? 'XX', // Default to unknown country
      eloRating: data['eloRating'] ?? 1200,
      wins: data['wins'] ?? 0,
      losses: data['losses'] ?? 0,
      totalRaces: data['totalRaces'] ?? 0,
      lastRaceAt: data['lastRaceAt'] != null
          ? (data['lastRaceAt'] as Timestamp).toDate()
          : null,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'country': country,
      'eloRating': eloRating,
      'wins': wins,
      'losses': losses,
      'totalRaces': totalRaces,
      'lastRaceAt': lastRaceAt != null ? Timestamp.fromDate(lastRaceAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy with updated fields
  RaceLeaderboardEntry copyWith({
    String? userId,
    String? displayName,
    String? country,
    int? eloRating,
    int? wins,
    int? losses,
    int? totalRaces,
    DateTime? lastRaceAt,
    DateTime? createdAt,
  }) {
    return RaceLeaderboardEntry(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      eloRating: eloRating ?? this.eloRating,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      totalRaces: totalRaces ?? this.totalRaces,
      lastRaceAt: lastRaceAt ?? this.lastRaceAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
