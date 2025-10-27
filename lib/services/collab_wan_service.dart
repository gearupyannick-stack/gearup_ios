// lib/services/collab_wan_service.dart
// WAN collaboration service using Cloud Firestore.
// - Rooms documents path: "gameRooms/{roomCode}"
// - Players subcollection: "gameRooms/{roomCode}/players/{playerId}"
// - Messages subcollection: "gameRooms/{roomCode}/messages/{autoId}"
//
// Usage:
//   final svc = CollabWanService();
//   final code = svc.generateRoomCode(); // or user-provided
//   await svc.createRoom(code, displayName: 'Yannick');
//   await svc.joinRoom(code, displayName: 'Yannick');
//   svc.playersStream(roomCode).listen(...);
//   svc.messagesStream(roomCode).listen(...);
//   svc.sendMessage(roomCode, {'type':'ping'});
//
// Requirements:
//   - Add cloud_firestore to pubspec.yaml
//   - Initialize Firebase in main.dart (see notes below)

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayerInfo {
  final String id;
  final String displayName;
  final DateTime lastSeen;
  final int score;
  final int errors;

  PlayerInfo({
    required this.id,
    required this.displayName,
    required this.lastSeen,
    this.score = 0,
    this.errors = 0,
  });

  factory PlayerInfo.fromMap(String id, Map<String, dynamic> m) {
    return PlayerInfo(
      id: id,
      displayName: m['displayName'] as String? ?? 'Guest',
      lastSeen: (m['lastSeen'] is Timestamp) ? (m['lastSeen'] as Timestamp).toDate() : DateTime.now(),
      score: m['score'] as int? ?? 0,
      errors: m['errors'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'displayName': displayName,
        'lastSeen': FieldValue.serverTimestamp(),
        'score': score,
        'errors': errors,
      };
}

class CollabMessage {
  final String id;
  final String senderId;
  final String senderName;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  CollabMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.payload,
    required this.timestamp,
  });

  factory CollabMessage.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return CollabMessage(
      id: doc.id,
      senderId: m['senderId'] as String? ?? '',
      senderName: m['senderName'] as String? ?? '',
      payload: Map<String, dynamic>.from(m['payload'] ?? <String, dynamic>{}),
      timestamp: (m['ts'] is Timestamp) ? (m['ts'] as Timestamp).toDate() : DateTime.now(),
    );
  }
}

class CollabWanService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // root collection
  static const String roomsCollection = 'gameRooms';
  static const String playersSub = 'players';
  static const String messagesSub = 'messages';

  String _localPlayerId = '';
  String get localPlayerId => _localPlayerId;

  /// Generate a human-friendly 6-char room code (A-Z0-9)
  String generateRoomCode({int length = 6}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // exclude ambiguous chars
    final rnd = Random.secure();
    return List.generate(length, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> _getOrMakeLocalPlayerId() async {
    // prefer Firebase UID if signed in, otherwise generate a short random id
    final user = _auth.currentUser;
    if (user != null && user.uid.isNotEmpty) {
      _localPlayerId = user.uid;
      return _localPlayerId;
    }
    if (_localPlayerId.isNotEmpty) return _localPlayerId;
    final rnd = Random.secure();
    _localPlayerId = 'guest_${rnd.nextInt(1 << 31)}';
    return _localPlayerId;
  }

  Future<void> createRoom(String roomCode, {required String displayName}) async {
    final roomRef = _db.collection(roomsCollection).doc(roomCode);
    final snap = await roomRef.get();
    if (!snap.exists) {
      await roomRef.set(<String, dynamic>{
        'createdAt': FieldValue.serverTimestamp(),
        'host': await _getOrMakeLocalPlayerId(),
        'meta': {'description': 'Room created via CollabWanService'},
      });
    }
    // join as player immediately
    await joinRoom(roomCode, displayName: displayName);
  }

  Future<bool> roomExists(String roomCode) async {
    final snap = await _db.collection(roomsCollection).doc(roomCode).get();
    return snap.exists;
  }

  Future<void> joinRoom(String roomCode, {required String displayName}) async {
    final pid = await _getOrMakeLocalPlayerId();
    final playerRef = _db.collection(roomsCollection).doc(roomCode).collection(playersSub).doc(pid);
    await playerRef.set(<String, dynamic>{
      'displayName': displayName,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    // optional: create messages subcollection when joining
    final roomRef = _db.collection(roomsCollection).doc(roomCode);
    await roomRef.set({'lastJoin': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Update presence timestamp (call periodically from UI / timer)
  Future<void> touchPresence(String roomCode) async {
    final pid = await _getOrMakeLocalPlayerId();
    final playerRef = _db.collection(roomsCollection).doc(roomCode).collection(playersSub).doc(pid);
    await playerRef.set({'lastSeen': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Remove presence (leave)
  Future<void> leaveRoom(String roomCode) async {
    if (_localPlayerId.isEmpty) await _getOrMakeLocalPlayerId();
    final playerRef = _db.collection(roomsCollection).doc(roomCode).collection(playersSub).doc(_localPlayerId);
    try {
      await playerRef.delete();
    } catch (_) {}
  }

  /// Listen realtime to players list (Stream of PlayerInfo)
  Stream<List<PlayerInfo>> playersStream(String roomCode) {
    final coll = _db.collection(roomsCollection).doc(roomCode).collection(playersSub);
    return coll.snapshots().map((snap) {
      return snap.docs.map((d) => PlayerInfo.fromMap(d.id, d.data())).toList();
    });
  }

  /// Send a JSON payload message (any small JSON-serializable map)
  Future<void> sendMessage(String roomCode, Map<String, dynamic> payload) async {
    final pid = await _getOrMakeLocalPlayerId();
    final pname = (_auth.currentUser?.displayName) ?? pid;
    final messages = _db.collection(roomsCollection).doc(roomCode).collection(messagesSub);
    await messages.add(<String, dynamic>{
      'senderId': pid,
      'senderName': pname,
      'payload': payload,
      'ts': FieldValue.serverTimestamp(),
    });
  }

  /// Stream messages ordered by timestamp
  Stream<List<CollabMessage>> messagesStream(String roomCode, {int limit = 100}) {
    final messages = _db
        .collection(roomsCollection)
        .doc(roomCode)
        .collection(messagesSub)
        .orderBy('ts', descending: false)
        .limit(limit);
    return messages.snapshots().map((snap) => snap.docs.map((d) => CollabMessage.fromDoc(d)).toList());
  }

  /// Optional: cleanup old players that didn't update presence for > TTL seconds.
  /// Note: this function performs deletion client-side; better to use a Cloud Function for production.
  Future<void> cleanupStalePlayers(String roomCode, {Duration ttl = const Duration(seconds: 30)}) async {
    final cutoff = DateTime.now().subtract(ttl);
    final coll = _db.collection(roomsCollection).doc(roomCode).collection(playersSub);
    final snap = await coll.where('lastSeen', isLessThan: Timestamp.fromDate(cutoff)).get();
    for (final d in snap.docs) {
      try {
        await d.reference.delete();
      } catch (_) {}
    }
  }
}