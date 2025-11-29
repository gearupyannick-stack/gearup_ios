import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/club_member.dart';
import '../services/chat_service.dart';
import '../services/leaderboard_service.dart';

/// Service for managing club race statistics and rewards
/// Handles dual reward system: global ELO + club-specific points
class ClubRaceService {
  static final ClubRaceService instance = ClubRaceService._internal();
  ClubRaceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Club points awarded based on placement
  static const Map<int, int> PLACEMENT_POINTS = {
    1: 100, // 1st place
    2: 75,  // 2nd place
    3: 50,  // 3rd place
    4: 35,  // 4th place
    5: 25,  // 5th place
  };
  static const int PERFECT_SCORE_BONUS = 25;
  static const int SPEED_BONUS = 10;
  static const int PARTICIPATION_POINTS = 10; // Everyone gets 10pts for participating

  /// Calculate club points for a race result
  /// placement: 1-indexed (1 = winner, 2 = second, etc.)
  /// score: number of correct answers
  /// errors: number of wrong answers
  /// totalQuestions: total questions in race
  /// raceTimeSeconds: time taken to complete race
  int calculateClubPoints({
    required int placement,
    required int score,
    required int errors,
    required int totalQuestions,
    required int raceTimeSeconds,
  }) {
    int points = PARTICIPATION_POINTS;

    // Placement bonus
    points += PLACEMENT_POINTS[placement] ?? (placement <= 10 ? 15 : 5);

    // Perfect score bonus
    if (score == totalQuestions && errors == 0) {
      points += PERFECT_SCORE_BONUS;
    }

    // Speed bonus (if finished in under 2 minutes for 10 questions, scaled for other lengths)
    final targetTime = (totalQuestions / 10) * 120; // 120 seconds for 10 questions
    if (raceTimeSeconds < targetTime) {
      points += SPEED_BONUS;
    }

    return points;
  }

  /// Update member stats after completing a club race
  /// Returns the points earned
  Future<int> updateMemberStatsAfterRace({
    required String clubId,
    required String userId,
    required int placement,
    required int score,
    required int errors,
    required int totalQuestions,
    required int raceTimeSeconds,
  }) async {
    try {
      final memberRef = _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .doc(userId);

      final memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        print('Member not found in club: $userId');
        return 0;
      }

      final member = ClubMember.fromFirestore(memberDoc);

      // Calculate points earned
      final pointsEarned = calculateClubPoints(
        placement: placement,
        score: score,
        errors: errors,
        totalQuestions: totalQuestions,
        raceTimeSeconds: raceTimeSeconds,
      );

      // Calculate new average score
      final oldAverage = member.averageRaceScore ?? 0.0;
      final oldCount = member.clubRacesCompleted;
      final newAverage = ((oldAverage * oldCount) + score) / (oldCount + 1);

      // Update best race time (lower is better)
      final newBestTime = member.bestRaceTime == null
          ? raceTimeSeconds
          : (raceTimeSeconds < member.bestRaceTime! ? raceTimeSeconds : member.bestRaceTime);

      // Update member stats
      await memberRef.update({
        'clubRacesCompleted': FieldValue.increment(1),
        'clubRacesWon': placement == 1 ? FieldValue.increment(1) : member.clubRacesWon,
        'clubPoints': FieldValue.increment(pointsEarned),
        'averageRaceScore': newAverage,
        'bestRaceTime': newBestTime,
        'lastSeenAt': FieldValue.serverTimestamp(),
      });

      return pointsEarned;
    } catch (e) {
      print('Error updating member stats: $e');
      return 0;
    }
  }

  /// Process race results for all participants in a club race
  /// Updates stats and ELO, posts results to chat
  Future<void> processClubRaceResults({
    required String clubId,
    required String clubName,
    required String challengeId,
    required String roomCode,
    required List<Map<String, dynamic>> results, // [{userId, displayName, score, errors, time}]
    required int totalQuestions,
  }) async {
    try {
      // Sort by score (descending) to determine placements
      results.sort((a, b) {
        final scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
        if (scoreCompare != 0) return scoreCompare;
        // If scores are equal, faster time wins
        return (a['time'] as int).compareTo(b['time'] as int);
      });

      // Process each participant
      final Map<String, int> userPoints = {};
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        final placement = i + 1;
        final userId = result['userId'] as String;

        // Update club stats
        final points = await updateMemberStatsAfterRace(
          clubId: clubId,
          userId: userId,
          placement: placement,
          score: result['score'] as int,
          errors: result['errors'] as int,
          totalQuestions: totalQuestions,
          raceTimeSeconds: result['time'] as int,
        );

        userPoints[userId] = points;
      }

      // Update global ELO ratings (only for 1v1 races)
      if (results.length == 2) {
        final winner = results[0];
        final loser = results[1];
        await LeaderboardService().updateRatingsAfterRace(
          winnerId: winner['userId'] as String,
          loserId: loser['userId'] as String,
          winnerName: winner['displayName'] as String,
          loserName: loser['displayName'] as String,
        );
      }

      // Mark race challenge as completed
      await _firestore
          .collection('clubs')
          .doc(clubId)
          .collection('raceChallenges')
          .doc(challengeId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Post results to club chat
      await _postRaceResultsToChat(
        clubId: clubId,
        clubName: clubName,
        results: results,
        userPoints: userPoints,
        totalQuestions: totalQuestions,
      );

    } catch (e) {
      print('Error processing club race results: $e');
    }
  }

  /// Post race results as a system message in club chat
  Future<void> _postRaceResultsToChat({
    required String clubId,
    required String clubName,
    required List<Map<String, dynamic>> results,
    required Map<String, int> userPoints,
    required int totalQuestions,
  }) async {
    try {
      final winner = results.first;
      final winnerName = winner['displayName'] as String;
      final winnerScore = winner['score'] as int;
      final winnerPoints = userPoints[winner['userId']] ?? 0;

      // Build results summary
      final buffer = StringBuffer();
      buffer.writeln('🏁 Race Complete!');
      buffer.writeln('');
      buffer.writeln('🏆 Winner: $winnerName');
      buffer.writeln('   Score: $winnerScore/$totalQuestions');
      buffer.writeln('   Points: +$winnerPoints');

      if (results.length > 1) {
        buffer.writeln('');
        buffer.writeln('Standings:');
        for (int i = 0; i < results.length && i < 5; i++) {
          final result = results[i];
          final place = i + 1;
          final emoji = place == 1 ? '🥇' : place == 2 ? '🥈' : place == 3 ? '🥉' : '$place.';
          final name = result['displayName'] as String;
          final score = result['score'] as int;
          final points = userPoints[result['userId']] ?? 0;
          buffer.writeln('   $emoji $name: $score/$totalQuestions (+$points pts)');
        }
      }

      // Send system message
      await ChatService.instance.sendSystemMessage(
        clubId: clubId,
        content: buffer.toString(),
      );

    } catch (e) {
      print('Error posting race results to chat: $e');
    }
  }

  /// Get top point earners in a club
  Stream<List<ClubMember>> getTopPointEarnersStream(String clubId, {int limit = 10}) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .orderBy('clubPoints', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClubMember.fromFirestore(doc))
            .toList());
  }

  /// Get most active racers in a club
  Stream<List<ClubMember>> getMostActiveRacersStream(String clubId, {int limit = 10}) {
    return _firestore
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .orderBy('clubRacesCompleted', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClubMember.fromFirestore(doc))
            .toList());
  }
}
