import 'package:cloud_firestore/cloud_firestore.dart';

enum ClubVisibility { public, private }

enum ClubRole { owner, moderator, member }

class Club {
  final String clubId;
  final String name;
  final String description;
  final String inviteCode;
  final ClubVisibility visibility;
  final String ownerId;
  final String ownerDisplayName;
  final List<String> moderatorIds;
  final DateTime createdAt;
  final int memberCount;
  final int maxMembers;
  final bool allowInstantRaces;
  final bool allowScheduledRaces;
  final bool allowTournaments;
  final int totalRaces;
  final int totalTournaments;
  final DateTime lastActivityAt;
  final String? iconUrl;
  final String? primaryColor;

  Club({
    required this.clubId,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.visibility,
    required this.ownerId,
    required this.ownerDisplayName,
    required this.moderatorIds,
    required this.createdAt,
    required this.memberCount,
    required this.maxMembers,
    this.allowInstantRaces = true,
    this.allowScheduledRaces = true,
    this.allowTournaments = true,
    this.totalRaces = 0,
    this.totalTournaments = 0,
    required this.lastActivityAt,
    this.iconUrl,
    this.primaryColor,
  });

  factory Club.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Club(
      clubId: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      visibility: data['visibility'] == 'public'
          ? ClubVisibility.public
          : ClubVisibility.private,
      ownerId: data['ownerId'] ?? '',
      ownerDisplayName: data['ownerDisplayName'] ?? '',
      moderatorIds: List<String>.from(data['moderatorIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberCount: data['memberCount'] ?? 0,
      maxMembers: data['maxMembers'] ?? 50,
      allowInstantRaces: data['allowInstantRaces'] ?? true,
      allowScheduledRaces: data['allowScheduledRaces'] ?? true,
      allowTournaments: data['allowTournaments'] ?? true,
      totalRaces: data['totalRaces'] ?? 0,
      totalTournaments: data['totalTournaments'] ?? 0,
      lastActivityAt: (data['lastActivityAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      iconUrl: data['iconUrl'],
      primaryColor: data['primaryColor'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'name': name,
      'description': description,
      'inviteCode': inviteCode,
      'visibility': visibility == ClubVisibility.public ? 'public' : 'private',
      'ownerId': ownerId,
      'ownerDisplayName': ownerDisplayName,
      'moderatorIds': moderatorIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'allowInstantRaces': allowInstantRaces,
      'allowScheduledRaces': allowScheduledRaces,
      'allowTournaments': allowTournaments,
      'totalRaces': totalRaces,
      'totalTournaments': totalTournaments,
      'lastActivityAt': Timestamp.fromDate(lastActivityAt),
      if (iconUrl != null) 'iconUrl': iconUrl,
      if (primaryColor != null) 'primaryColor': primaryColor,
    };
  }

  Club copyWith({
    String? clubId,
    String? name,
    String? description,
    String? inviteCode,
    ClubVisibility? visibility,
    String? ownerId,
    String? ownerDisplayName,
    List<String>? moderatorIds,
    DateTime? createdAt,
    int? memberCount,
    int? maxMembers,
    bool? allowInstantRaces,
    bool? allowScheduledRaces,
    bool? allowTournaments,
    int? totalRaces,
    int? totalTournaments,
    DateTime? lastActivityAt,
    String? iconUrl,
    String? primaryColor,
  }) {
    return Club(
      clubId: clubId ?? this.clubId,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      visibility: visibility ?? this.visibility,
      ownerId: ownerId ?? this.ownerId,
      ownerDisplayName: ownerDisplayName ?? this.ownerDisplayName,
      moderatorIds: moderatorIds ?? this.moderatorIds,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      allowInstantRaces: allowInstantRaces ?? this.allowInstantRaces,
      allowScheduledRaces: allowScheduledRaces ?? this.allowScheduledRaces,
      allowTournaments: allowTournaments ?? this.allowTournaments,
      totalRaces: totalRaces ?? this.totalRaces,
      totalTournaments: totalTournaments ?? this.totalTournaments,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      iconUrl: iconUrl ?? this.iconUrl,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }

  bool get isPublic => visibility == ClubVisibility.public;
  bool get isFull => memberCount >= maxMembers;
}
