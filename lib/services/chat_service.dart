import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chat_message.dart';
import '../models/race_challenge.dart';
import 'club_notification_service.dart';
import 'club_service.dart';

class ChatService {
  static final ChatService instance = ChatService._internal();
  ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Chat Messages

  /// Send a text message
  Future<String> sendMessage({
    required String clubId,
    required String content,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final messageId = _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc()
        .id;

    final message = ChatMessage(
      messageId: messageId,
      clubId: clubId,
      senderId: user.uid,
      senderDisplayName: user.displayName ?? 'User',
      content: content.trim(),
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc(messageId)
        .set(message.toFirestore());

    // Update club's last activity
    await _db.collection('clubs').doc(clubId).update({
      'lastActivityAt': FieldValue.serverTimestamp(),
    });

    return messageId;
  }

  /// Send a system message
  Future<String> sendSystemMessage({
    required String clubId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final messageId = _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc()
        .id;

    final message = ChatMessage(
      messageId: messageId,
      clubId: clubId,
      senderId: 'system',
      senderDisplayName: 'System',
      content: content,
      type: MessageType.system,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc(messageId)
        .set(message.toFirestore());

    return messageId;
  }

  /// Get messages stream
  Stream<List<ChatMessage>> getMessagesStream(String clubId, {int limit = 100}) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromFirestore(doc))
            .toList()
            .reversed
            .toList());
  }

  /// Delete a message (moderator/owner only)
  Future<void> deleteMessage(String clubId, String messageId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc(messageId)
        .delete();
  }

  // Race Challenges

  /// Create a race challenge
  Future<String> createRaceChallenge({
    required String clubId,
    required ChallengeType type,
    DateTime? scheduledTime,
    required int maxParticipants,
    required int questionsCount,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (type == ChallengeType.scheduled && scheduledTime == null) {
      throw Exception('Scheduled races must have a scheduled time');
    }

    final challengeId = _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc()
        .id;

    final challenge = RaceChallenge(
      challengeId: challengeId,
      clubId: clubId,
      creatorId: user.uid,
      creatorDisplayName: user.displayName ?? 'User',
      type: type,
      scheduledTime: scheduledTime,
      maxParticipants: maxParticipants,
      questionsCount: questionsCount,
      participantIds: [user.uid], // Creator auto-joins
      status: ChallengeStatus.open,
      createdAt: DateTime.now(),
    );

    // Create challenge document
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .set(challenge.toFirestore());

    // Send challenge message in chat
    final messageId = _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc()
        .id;

    final message = ChatMessage(
      messageId: messageId,
      clubId: clubId,
      senderId: user.uid,
      senderDisplayName: user.displayName ?? 'User',
      content: type == ChallengeType.instant
          ? 'Started an instant race challenge!'
          : 'Scheduled a race for later!',
      type: MessageType.raceChallenge,
      timestamp: DateTime.now(),
      metadata: {'raceChallengeId': challengeId},
    );

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('chat')
        .doc(messageId)
        .set(message.toFirestore());

    // Send notifications to club members
    final club = await ClubService.instance.getClub(clubId);
    if (club != null) {
      await ClubNotificationService.instance.sendNotificationToClub(
        clubId: clubId,
        clubName: club.name,
        type: ClubNotificationType.raceChallenge,
        title: 'New Race Challenge!',
        message: '${user.displayName ?? "Someone"} started a race challenge',
        excludeUserId: user.uid,
        metadata: {'raceChallengeId': challengeId},
      );
    }

    return challengeId;
  }

  /// Join a race challenge
  Future<void> joinRaceChallenge(String clubId, String challengeId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final challengeDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) throw Exception('Challenge not found');

    final challenge = RaceChallenge.fromFirestore(challengeDoc);

    if (challenge.isFull) throw Exception('Challenge is full');
    if (!challenge.isOpen) throw Exception('Challenge is no longer open');
    if (challenge.isParticipant(user.uid)) {
      throw Exception('Already joined this challenge');
    }

    // Add user to participants
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .update({
      'participantIds': FieldValue.arrayUnion([user.uid]),
    });

    // Send system message
    await sendSystemMessage(
      clubId: clubId,
      content: '${user.displayName ?? "User"} joined the race!',
      metadata: {'raceChallengeId': challengeId},
    );

    // Check if should auto-start (instant race and now full)
    if (challenge.isInstant && challenge.spotsLeft == 1) {
      // Will be full after this join
      await _startRaceChallenge(clubId, challengeId);
    }
  }

  /// Leave a race challenge
  Future<void> leaveRaceChallenge(String clubId, String challengeId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final challengeDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) throw Exception('Challenge not found');

    final challenge = RaceChallenge.fromFirestore(challengeDoc);

    if (!challenge.isParticipant(user.uid)) {
      throw Exception('Not a participant');
    }

    if (challenge.isActive) {
      throw Exception('Cannot leave an active race');
    }

    // Remove user from participants
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .update({
      'participantIds': FieldValue.arrayRemove([user.uid]),
    });

    // If creator left and challenge is open, cancel it
    if (challenge.creatorId == user.uid && challenge.isOpen) {
      await cancelRaceChallenge(clubId, challengeId);
    }
  }

  /// Cancel a race challenge
  Future<void> cancelRaceChallenge(String clubId, String challengeId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .update({
      'status': ChallengeStatus.cancelled.name,
    });

    await sendSystemMessage(
      clubId: clubId,
      content: 'Race challenge was cancelled.',
      metadata: {'raceChallengeId': challengeId},
    );
  }

  /// Start a race challenge (internal)
  Future<void> _startRaceChallenge(String clubId, String challengeId) async {
    // Generate a unique room code
    final roomCode = _generateRoomCode();

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .update({
      'status': ChallengeStatus.active.name,
      'roomCode': roomCode,
    });

    await sendSystemMessage(
      clubId: clubId,
      content: 'Race is starting! Room code: $roomCode',
      metadata: {
        'raceChallengeId': challengeId,
        'roomCode': roomCode,
      },
    );
  }

  /// Manually start a race challenge (creator only)
  Future<String> startRaceChallenge(String clubId, String challengeId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final challengeDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .get();

    if (!challengeDoc.exists) throw Exception('Challenge not found');

    final challenge = RaceChallenge.fromFirestore(challengeDoc);

    if (challenge.creatorId != user.uid) {
      throw Exception('Only the creator can start the race');
    }

    if (!challenge.isOpen) {
      throw Exception('Challenge is not open');
    }

    if (challenge.participantIds.length < 2) {
      throw Exception('Need at least 2 participants to start');
    }

    await _startRaceChallenge(clubId, challengeId);

    // Fetch and return the room code
    final updatedDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .get();

    return RaceChallenge.fromFirestore(updatedDoc).roomCode ?? '';
  }

  /// Complete a race challenge
  Future<void> completeRaceChallenge(String clubId, String challengeId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .update({
      'status': ChallengeStatus.completed.name,
    });
  }

  /// Get race challenge by ID
  Future<RaceChallenge?> getRaceChallenge(String clubId, String challengeId) async {
    final doc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .get();

    if (!doc.exists) return null;
    return RaceChallenge.fromFirestore(doc);
  }

  /// Get race challenge stream
  Stream<RaceChallenge> getRaceChallengeStream(String clubId, String challengeId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .doc(challengeId)
        .snapshots()
        .map((doc) => RaceChallenge.fromFirestore(doc));
  }

  /// Get open race challenges stream
  Stream<List<RaceChallenge>> getOpenRaceChallengesStream(String clubId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('raceChallenges')
        .where('status', isEqualTo: ChallengeStatus.open.name)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RaceChallenge.fromFirestore(doc))
            .toList());
  }

  // Helper methods

  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    var seed = random;

    for (var i = 0; i < 6; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      code += chars[seed % chars.length];
    }

    return code;
  }
}
