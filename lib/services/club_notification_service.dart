import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum ClubNotificationType {
  newMessage,
  raceChallenge,
  raceChallengeStarting,
  memberJoined,
  memberLeft,
}

class ClubNotification {
  final String notificationId;
  final String clubId;
  final String clubName;
  final ClubNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final bool isRead;

  ClubNotification({
    required this.notificationId,
    required this.clubId,
    required this.clubName,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.metadata,
    this.isRead = false,
  });

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'clubName': clubName,
      'type': type.name,
      'title': title,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      if (metadata != null) 'metadata': metadata,
      'isRead': isRead,
    };
  }

  // Create from Firestore
  factory ClubNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClubNotification(
      notificationId: doc.id,
      clubId: data['clubId'] ?? '',
      clubName: data['clubName'] ?? '',
      type: ClubNotificationType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ClubNotificationType.newMessage,
      ),
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
      isRead: data['isRead'] ?? false,
    );
  }
}

class ClubNotificationService {
  static final ClubNotificationService instance = ClubNotificationService._internal();
  ClubNotificationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamController<ClubNotification>? _notificationController;
  StreamSubscription? _notificationSubscription;

  /// Initialize notification listener
  void initialize(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return;

    _notificationController = StreamController<ClubNotification>.broadcast();

    // Listen to user's notifications
    _notificationSubscription = _db
        .collection('users')
        .doc(user.uid)
        .collection('clubNotifications')
        .where('isRead', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = ClubNotification.fromFirestore(change.doc);
          _notificationController?.add(notification);

          // Show in-app snackbar notification
          _showInAppNotification(context, notification);
        }
      }
    });
  }

  /// Dispose notification listener
  void dispose() {
    _notificationSubscription?.cancel();
    _notificationController?.close();
  }

  /// Send notification to a user
  Future<void> sendNotification({
    required String userId,
    required String clubId,
    required String clubName,
    required ClubNotificationType type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final notificationId = _db
        .collection('users')
        .doc(userId)
        .collection('clubNotifications')
        .doc()
        .id;

    final notification = ClubNotification(
      notificationId: notificationId,
      clubId: clubId,
      clubName: clubName,
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
      isRead: false,
    );

    await _db
        .collection('users')
        .doc(userId)
        .collection('clubNotifications')
        .doc(notificationId)
        .set(notification.toFirestore());
  }

  /// Send notification to all club members
  Future<void> sendNotificationToClub({
    required String clubId,
    required String clubName,
    required ClubNotificationType type,
    required String title,
    required String message,
    String? excludeUserId, // Don't notify this user
    Map<String, dynamic>? metadata,
  }) async {
    // Get all club members
    final membersSnapshot = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .get();

    final batch = _db.batch();

    for (var memberDoc in membersSnapshot.docs) {
      final userId = memberDoc.id;

      // Skip excluded user
      if (userId == excludeUserId) continue;

      final notificationRef = _db
          .collection('users')
          .doc(userId)
          .collection('clubNotifications')
          .doc();

      final notification = ClubNotification(
        notificationId: notificationRef.id,
        clubId: clubId,
        clubName: clubName,
        type: type,
        title: title,
        message: message,
        timestamp: DateTime.now(),
        metadata: metadata,
        isRead: false,
      );

      batch.set(notificationRef, notification.toFirestore());
    }

    await batch.commit();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('clubNotifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Get unread count
  Stream<int> getUnreadCountStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(0);

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('clubNotifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Show in-app notification
  void _showInAppNotification(BuildContext context, ClubNotification notification) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getIconForType(notification.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF3D0000),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // TODO: Navigate to relevant club/chat
            markAsRead(notification.notificationId);
          },
        ),
      ),
    );
  }

  IconData _getIconForType(ClubNotificationType type) {
    switch (type) {
      case ClubNotificationType.newMessage:
        return Icons.chat_bubble;
      case ClubNotificationType.raceChallenge:
        return Icons.emoji_events;
      case ClubNotificationType.raceChallengeStarting:
        return Icons.play_arrow;
      case ClubNotificationType.memberJoined:
        return Icons.person_add;
      case ClubNotificationType.memberLeft:
        return Icons.person_remove;
    }
  }
}
