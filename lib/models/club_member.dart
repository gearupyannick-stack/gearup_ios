import 'package:cloud_firestore/cloud_firestore.dart';
import 'club.dart';

class ClubMember {
  final String userId;
  final String displayName;
  final String country;
  final ClubRole role;
  final DateTime joinedAt;
  final DateTime lastSeenAt;
  final int clubRacesCompleted;
  final int clubRacesWon;
  final int clubPoints;
  final int clubTournamentsPlayed;
  final int clubTournamentsWon;
  final double? averageRaceScore;
  final int? bestRaceTime;

  ClubMember({
    required this.userId,
    required this.displayName,
    required this.country,
    required this.role,
    required this.joinedAt,
    required this.lastSeenAt,
    this.clubRacesCompleted = 0,
    this.clubRacesWon = 0,
    this.clubTournamentsPlayed = 0,
    this.clubTournamentsWon = 0,
  });

  factory ClubMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ClubMember(
      userId: doc.id,
      displayName: data['displayName'] ?? '',
      country: data['country'] ?? '',
      role: _parseRole(data['role']),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clubRacesCompleted: data['clubRacesCompleted'] ?? 0,
      clubRacesWon: data['clubRacesWon'] ?? 0,
      clubTournamentsPlayed: data['clubTournamentsPlayed'] ?? 0,
      clubTournamentsWon: data['clubTournamentsWon'] ?? 0,
    );
  }

  static ClubRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'owner':
        return ClubRole.owner;
      case 'moderator':
        return ClubRole.moderator;
      default:
        return ClubRole.member;
    }
  }

  static String _roleToString(ClubRole role) {
    switch (role) {
      case ClubRole.owner:
        return 'owner';
      case ClubRole.moderator:
        return 'moderator';
      case ClubRole.member:
        return 'member';
    }
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'country': country,
      'role': _roleToString(role),
      'joinedAt': Timestamp.fromDate(joinedAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'clubRacesCompleted': clubRacesCompleted,
      'clubRacesWon': clubRacesWon,
      'clubTournamentsPlayed': clubTournamentsPlayed,
      'clubTournamentsWon': clubTournamentsWon,
    };
  }

  ClubMember copyWith({
    String? userId,
    String? displayName,
    String? country,
    ClubRole? role,
    DateTime? joinedAt,
    DateTime? lastSeenAt,
    int? clubRacesCompleted,
    int? clubRacesWon,
    int? clubTournamentsPlayed,
    int? clubTournamentsWon,
  }) {
    return ClubMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      country: country ?? this.country,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      clubRacesCompleted: clubRacesCompleted ?? this.clubRacesCompleted,
      clubRacesWon: clubRacesWon ?? this.clubRacesWon,
      clubTournamentsPlayed: clubTournamentsPlayed ?? this.clubTournamentsPlayed,
      clubTournamentsWon: clubTournamentsWon ?? this.clubTournamentsWon,
    );
  }

  bool get isOwner => role == ClubRole.owner;
  bool get isModerator => role == ClubRole.moderator;
  bool get isMember => role == ClubRole.member;
  bool get hasModeratorPrivileges => role == ClubRole.owner || role == ClubRole.moderator;
}
