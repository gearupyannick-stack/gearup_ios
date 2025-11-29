import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club.dart';
import '../models/club_member.dart';

class ClubService {
  static final ClubService instance = ClubService._internal();
  ClubService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Club CRUD Operations

  /// Create a new club
  Future<String> createClub({
    required String name,
    required String description,
    required bool isPublic,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final clubId = _db.collection('clubs').doc().id;
    final inviteCode = await _generateUniqueInviteCode();
    final now = DateTime.now();

    final club = Club(
      clubId: clubId,
      name: name.trim(),
      description: description.trim(),
      inviteCode: inviteCode,
      visibility: isPublic ? ClubVisibility.public : ClubVisibility.private,
      ownerId: user.uid,
      ownerDisplayName: user.displayName ?? 'User',
      moderatorIds: [],
      createdAt: now,
      memberCount: 1,
      maxMembers: 50,
      lastActivityAt: now,
    );

    // Create club document
    await _db.collection('clubs').doc(clubId).set(club.toFirestore());

    // Add creator as owner member
    final member = ClubMember(
      userId: user.uid,
      displayName: user.displayName ?? 'User',
      country: '', // Will be populated from leaderboard if available
      role: ClubRole.owner,
      joinedAt: now,
      lastSeenAt: now,
    );

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(user.uid)
        .set(member.toFirestore());

    return clubId;
  }

  /// Get a club by ID
  Future<Club?> getClub(String clubId) async {
    final doc = await _db.collection('clubs').doc(clubId).get();
    if (!doc.exists) return null;
    return Club.fromFirestore(doc);
  }

  /// Update club fields
  Future<void> updateClub(String clubId, Map<String, dynamic> updates) async {
    await _db.collection('clubs').doc(clubId).update(updates);
  }

  /// Delete a club (owner only)
  Future<void> deleteClub(String clubId) async {
    // Delete all subcollections (members, chat, tournaments)
    final batch = _db.batch();

    // Delete members
    final membersSnapshot = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .get();
    for (var doc in membersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete club document
    batch.delete(_db.collection('clubs').doc(clubId));

    await batch.commit();
  }

  // Discovery

  /// Get stream of public clubs for discovery
  Stream<List<Club>> getPublicClubsStream({int limit = 20}) {
    return _db
        .collection('clubs')
        .where('visibility', isEqualTo: 'public')
        .orderBy('memberCount', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  /// Find club by invite code
  Future<Club?> findClubByInviteCode(String inviteCode) async {
    final snapshot = await _db
        .collection('clubs')
        .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Club.fromFirestore(snapshot.docs.first);
  }

  /// Generate a unique 6-character invite code
  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Generate unique invite code (checks for duplicates)
  Future<String> _generateUniqueInviteCode() async {
    String code;
    bool isUnique = false;

    do {
      code = generateInviteCode();
      isUnique = await isInviteCodeAvailable(code);
    } while (!isUnique);

    return code;
  }

  /// Check if invite code is available
  Future<bool> isInviteCodeAvailable(String code) async {
    final snapshot = await _db
        .collection('clubs')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    return snapshot.docs.isEmpty;
  }

  // Membership Management

  /// Join a club
  Future<void> joinClub(String clubId, String userId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check if club is full
    final club = await getClub(clubId);
    if (club == null) throw Exception('Club not found');
    if (club.isFull) throw Exception('Club is full');

    // Check if already a member
    final isMemberAlready = await isMember(clubId, userId);
    if (isMemberAlready) throw Exception('Already a member');

    final now = DateTime.now();

    // Add member
    final member = ClubMember(
      userId: userId,
      displayName: user.displayName ?? 'User',
      country: '', // Will be populated from leaderboard if available
      role: ClubRole.member,
      joinedAt: now,
      lastSeenAt: now,
    );

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .set(member.toFirestore());

    // Increment member count
    await _db.collection('clubs').doc(clubId).update({
      'memberCount': FieldValue.increment(1),
      'lastActivityAt': FieldValue.serverTimestamp(),
    });
  }

  /// Leave a club
  Future<void> leaveClub(String clubId, String userId) async {
    final member = await _getMember(clubId, userId);
    if (member == null) throw Exception('Not a member of this club');

    // Owner cannot leave (must transfer ownership or delete club)
    if (member.isOwner) {
      throw Exception('Owner cannot leave. Transfer ownership or delete the club.');
    }

    // Remove member
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .delete();

    // Decrement member count
    await _db.collection('clubs').doc(clubId).update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  /// Kick a member (moderator or owner only)
  Future<void> kickMember(String clubId, String userId) async {
    final targetMember = await _getMember(clubId, userId);
    if (targetMember == null) throw Exception('User is not a member');

    // Cannot kick owner
    if (targetMember.isOwner) {
      throw Exception('Cannot kick the club owner');
    }

    // Remove member
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .delete();

    // Decrement member count
    await _db.collection('clubs').doc(clubId).update({
      'memberCount': FieldValue.increment(-1),
    });
  }

  /// Get members stream
  Stream<List<ClubMember>> getMembersStream(String clubId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .orderBy('role')
        .orderBy('joinedAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ClubMember.fromFirestore(doc)).toList());
  }

  /// Get member count
  Future<int> getMemberCount(String clubId) async {
    final club = await getClub(clubId);
    return club?.memberCount ?? 0;
  }

  /// Check if user is a member
  Future<bool> isMember(String clubId, String userId) async {
    final doc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .get();

    return doc.exists;
  }

  /// Check if club is full
  Future<bool> isClubFull(String clubId) async {
    final club = await getClub(clubId);
    return club?.isFull ?? false;
  }

  // Role Management

  /// Promote member to moderator (owner only)
  Future<void> promoteMember(String clubId, String userId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .update({'role': 'moderator'});

    // Add to moderator list in club document
    await _db.collection('clubs').doc(clubId).update({
      'moderatorIds': FieldValue.arrayUnion([userId]),
    });
  }

  /// Demote member from moderator to regular member (owner only)
  Future<void> demoteMember(String clubId, String userId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .update({'role': 'member'});

    // Remove from moderator list in club document
    await _db.collection('clubs').doc(clubId).update({
      'moderatorIds': FieldValue.arrayRemove([userId]),
    });
  }

  /// Get member's role
  Future<ClubRole> getMemberRole(String clubId, String userId) async {
    final member = await _getMember(clubId, userId);
    return member?.role ?? ClubRole.member;
  }

  // User's Clubs

  /// Get stream of clubs user is a member of
  Stream<List<Club>> getUserClubsStream(String userId) {
    late StreamController<List<Club>> controller;
    Timer? periodicTimer;

    void startListening() {
      // Initial load
      _loadUserClubs(userId).then((clubs) {
        if (!controller.isClosed) {
          controller.add(clubs);
        }
      }).catchError((error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      });

      // Periodic refresh every 5 seconds
      periodicTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
        if (controller.isClosed) {
          timer.cancel();
          return;
        }

        try {
          final clubs = await _loadUserClubs(userId);
          if (!controller.isClosed) {
            controller.add(clubs);
          }
        } catch (error) {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        }
      });
    }

    void stopListening() {
      periodicTimer?.cancel();
    }

    controller = StreamController<List<Club>>.broadcast(
      onListen: startListening,
      onCancel: stopListening,
    );

    return controller.stream;
  }

  /// Load user's clubs
  Future<List<Club>> _loadUserClubs(String userId) async {
    // Get all clubs where user is a member
    final clubIds = await getUserClubIds(userId);

    if (clubIds.isEmpty) {
      return [];
    }

    // Fetch all clubs (Firestore 'in' query limited to 10 items)
    final clubs = <Club>[];
    for (var i = 0; i < clubIds.length; i += 10) {
      final batch = clubIds.skip(i).take(10).toList();
      final snapshot = await _db
          .collection('clubs')
          .where(FieldPath.documentId, whereIn: batch)
          .get();

      clubs.addAll(snapshot.docs.map((doc) => Club.fromFirestore(doc)));
    }

    return clubs;
  }

  /// Get list of club IDs user is a member of
  Future<List<String>> getUserClubIds(String userId) async {
    final clubsSnapshot = await _db.collection('clubs').get();
    final clubIds = <String>[];

    for (var clubDoc in clubsSnapshot.docs) {
      final memberDoc = await clubDoc.reference.collection('members').doc(userId).get();
      if (memberDoc.exists) {
        clubIds.add(clubDoc.id);
      }
    }

    return clubIds;
  }

  // Helper Methods

  Future<ClubMember?> _getMember(String clubId, String userId) async {
    final doc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(userId)
        .get();

    if (!doc.exists) return null;
    return ClubMember.fromFirestore(doc);
  }
}
