import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/race_leaderboard_entry.dart';

/// Service for managing the competitive race leaderboard with ELO rating system
class LeaderboardService {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String COLLECTION_NAME = 'raceLeaderboard';
  static const int STARTING_ELO = 0;
  static const int K_FACTOR_NEW = 32; // For players with < 30 races
  static const int K_FACTOR_EXPERIENCED = 24; // For players with >= 30 races
  static const int EXPERIENCE_THRESHOLD = 30;

  /// Get the current user's ID (Firebase UID or guest ID)
  String? get currentUserId => _auth.currentUser?.uid;

  /// Initialize a new player's leaderboard entry
  Future<void> initializePlayer({
    required String userId,
    required String displayName,
    required String country,
  }) async {
    try {
      final docRef = _firestore.collection(COLLECTION_NAME).doc(userId);
      final doc = await docRef.get();

      if (!doc.exists) {
        final entry = RaceLeaderboardEntry(
          userId: userId,
          displayName: displayName,
          country: country,
          eloRating: STARTING_ELO,
          wins: 0,
          losses: 0,
          totalRaces: 0,
          createdAt: DateTime.now(),
        );
        await docRef.set(entry.toFirestore());
      }
    } catch (e) {
      print('Error initializing player leaderboard: $e');
    }
  }

  /// Fetch top N players by ELO rating
  Stream<List<RaceLeaderboardEntry>> getTopPlayersStream({int limit = 10}) {
    return _firestore
        .collection(COLLECTION_NAME)
        .orderBy('eloRating', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RaceLeaderboardEntry.fromFirestore(doc))
            .toList());
  }

  /// Fetch a specific player's leaderboard entry
  Future<RaceLeaderboardEntry?> getPlayerEntry(String userId) async {
    try {
      final doc = await _firestore.collection(COLLECTION_NAME).doc(userId).get();
      if (doc.exists) {
        return RaceLeaderboardEntry.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching player entry: $e');
      return null;
    }
  }

  /// Get player's current rank (1-indexed)
  Future<int?> getPlayerRank(String userId) async {
    try {
      final playerEntry = await getPlayerEntry(userId);
      if (playerEntry == null) return null;

      final higherRatedCount = await _firestore
          .collection(COLLECTION_NAME)
          .where('eloRating', isGreaterThan: playerEntry.eloRating)
          .count()
          .get();

      return (higherRatedCount.count ?? 0) + 1;
    } catch (e) {
      print('Error calculating player rank: $e');
      return null;
    }
  }

  /// Calculate expected score for ELO rating system
  /// Returns a value between 0 and 1 representing expected win probability
  double _calculateExpectedScore(int playerRating, int opponentRating) {
    return 1.0 / (1.0 + pow(10, (opponentRating - playerRating) / 400.0));
  }

  /// Calculate K-factor based on player experience
  int _getKFactor(int totalRaces) {
    return totalRaces < EXPERIENCE_THRESHOLD ? K_FACTOR_NEW : K_FACTOR_EXPERIENCED;
  }

  /// Calculate new ELO rating after a match
  /// actualScore: 1 for win, 0 for loss
  int _calculateNewRating({
    required int currentRating,
    required int opponentRating,
    required double actualScore,
    required int totalRaces,
  }) {
    final expectedScore = _calculateExpectedScore(currentRating, opponentRating);
    final kFactor = _getKFactor(totalRaces);
    final ratingChange = (kFactor * (actualScore - expectedScore)).round();
    final newRating = currentRating + ratingChange;
    // Ensure rating never goes below 0
    return newRating < 0 ? 0 : newRating;
  }

  /// Update ratings after a 1v1 race completes
  /// Returns the rating changes [winnerChange, loserChange]
  Future<List<int>> updateRatingsAfterRace({
    required String winnerId,
    required String loserId,
    required String winnerName,
    required String loserName,
  }) async {
    try {
      // Use a transaction to ensure atomic updates
      final result = await _firestore.runTransaction<List<int>>((transaction) async {
        final winnerRef = _firestore.collection(COLLECTION_NAME).doc(winnerId);
        final loserRef = _firestore.collection(COLLECTION_NAME).doc(loserId);

        final winnerDoc = await transaction.get(winnerRef);
        final loserDoc = await transaction.get(loserRef);

        // Get current entries or create new ones
        RaceLeaderboardEntry winnerEntry;
        RaceLeaderboardEntry loserEntry;

        if (winnerDoc.exists) {
          winnerEntry = RaceLeaderboardEntry.fromFirestore(winnerDoc);
        } else {
          // Initialize new player
          final winnerCountry = await _getUserCountry(winnerId);
          winnerEntry = RaceLeaderboardEntry(
            userId: winnerId,
            displayName: winnerName,
            country: winnerCountry,
            eloRating: STARTING_ELO,
            wins: 0,
            losses: 0,
            totalRaces: 0,
            createdAt: DateTime.now(),
          );
        }

        if (loserDoc.exists) {
          loserEntry = RaceLeaderboardEntry.fromFirestore(loserDoc);
        } else {
          // Initialize new player
          final loserCountry = await _getUserCountry(loserId);
          loserEntry = RaceLeaderboardEntry(
            userId: loserId,
            displayName: loserName,
            country: loserCountry,
            eloRating: STARTING_ELO,
            wins: 0,
            losses: 0,
            totalRaces: 0,
            createdAt: DateTime.now(),
          );
        }

        // Calculate new ratings
        final winnerOldRating = winnerEntry.eloRating;
        final loserOldRating = loserEntry.eloRating;

        final winnerNewRating = _calculateNewRating(
          currentRating: winnerOldRating,
          opponentRating: loserOldRating,
          actualScore: 1.0, // Winner gets score of 1
          totalRaces: winnerEntry.totalRaces,
        );

        final loserNewRating = _calculateNewRating(
          currentRating: loserOldRating,
          opponentRating: winnerOldRating,
          actualScore: 0.0, // Loser gets score of 0
          totalRaces: loserEntry.totalRaces,
        );

        final winnerRatingChange = winnerNewRating - winnerOldRating;
        final loserRatingChange = loserNewRating - loserOldRating;

        // Update winner
        final updatedWinner = winnerEntry.copyWith(
          displayName: winnerName, // Update name in case it changed
          eloRating: winnerNewRating,
          wins: winnerEntry.wins + 1,
          totalRaces: winnerEntry.totalRaces + 1,
          lastRaceAt: DateTime.now(),
        );

        // Update loser
        final updatedLoser = loserEntry.copyWith(
          displayName: loserName, // Update name in case it changed
          eloRating: loserNewRating,
          losses: loserEntry.losses + 1,
          totalRaces: loserEntry.totalRaces + 1,
          lastRaceAt: DateTime.now(),
        );

        // Write updates
        transaction.set(winnerRef, updatedWinner.toFirestore());
        transaction.set(loserRef, updatedLoser.toFirestore());

        return [winnerRatingChange, loserRatingChange];
      });

      return result;
    } catch (e) {
      print('Error updating ratings after race: $e');
      return [0, 0];
    }
  }

  /// Get user's country from SharedPreferences
  Future<String> _getUserCountry(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('country') ?? 'XX'; // Default to unknown
    } catch (e) {
      return 'XX';
    }
  }

  /// Update player's country
  Future<void> updatePlayerCountry(String userId, String country) async {
    try {
      await _firestore.collection(COLLECTION_NAME).doc(userId).update({
        'country': country,
      });

      // Also save locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('country', country);
    } catch (e) {
      print('Error updating player country: $e');
    }
  }

  /// Get user's saved country from local storage
  Future<String?> getSavedCountry() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('country');
    } catch (e) {
      return null;
    }
  }

  /// Save country to local storage
  Future<void> saveCountryLocally(String country) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('country', country);
    } catch (e) {
      print('Error saving country locally: $e');
    }
  }
}
