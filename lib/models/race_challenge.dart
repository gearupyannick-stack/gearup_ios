import 'package:cloud_firestore/cloud_firestore.dart';

enum ChallengeType {
  instant,
  scheduled,
}

enum ChallengeStatus {
  open,
  active,
  completed,
  cancelled,
}

class RaceChallenge {
  final String challengeId;
  final String clubId;
  final String creatorId;
  final String creatorDisplayName;
  final ChallengeType type;
  final DateTime? scheduledTime;
  final int maxParticipants;
  final int questionsCount;
  final List<String> participantIds;
  final ChallengeStatus status;
  final DateTime createdAt;
  final String? roomCode; // Generated when race starts

  RaceChallenge({
    required this.challengeId,
    required this.clubId,
    required this.creatorId,
    required this.creatorDisplayName,
    required this.type,
    this.scheduledTime,
    required this.maxParticipants,
    required this.questionsCount,
    required this.participantIds,
    required this.status,
    required this.createdAt,
    this.roomCode,
  });

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'creatorId': creatorId,
      'creatorDisplayName': creatorDisplayName,
      'type': type.name,
      'scheduledTime': scheduledTime != null ? Timestamp.fromDate(scheduledTime!) : null,
      'maxParticipants': maxParticipants,
      'questionsCount': questionsCount,
      'participantIds': participantIds,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'roomCode': roomCode,
    };
  }

  // Create from Firestore
  factory RaceChallenge.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RaceChallenge(
      challengeId: doc.id,
      clubId: data['clubId'] ?? '',
      creatorId: data['creatorId'] ?? '',
      creatorDisplayName: data['creatorDisplayName'] ?? 'Unknown',
      type: ChallengeType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ChallengeType.instant,
      ),
      scheduledTime: (data['scheduledTime'] as Timestamp?)?.toDate(),
      maxParticipants: data['maxParticipants'] ?? 4,
      questionsCount: data['questionsCount'] ?? 10,
      participantIds: List<String>.from(data['participantIds'] ?? []),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ChallengeStatus.open,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      roomCode: data['roomCode'] as String?,
    );
  }

  // Helper getters
  bool get isInstant => type == ChallengeType.instant;
  bool get isScheduled => type == ChallengeType.scheduled;
  bool get isOpen => status == ChallengeStatus.open;
  bool get isActive => status == ChallengeStatus.active;
  bool get isCompleted => status == ChallengeStatus.completed;
  bool get isCancelled => status == ChallengeStatus.cancelled;
  bool get isFull => participantIds.length >= maxParticipants;

  int get spotsLeft => maxParticipants - participantIds.length;

  // Check if user is a participant
  bool isParticipant(String userId) => participantIds.contains(userId);

  // Time until scheduled race starts
  Duration? get timeUntilStart {
    if (scheduledTime == null) return null;
    return scheduledTime!.difference(DateTime.now());
  }

  // Should the race auto-start?
  bool get shouldAutoStart {
    if (isInstant && isFull) return true;
    if (isScheduled && scheduledTime != null) {
      return DateTime.now().isAfter(scheduledTime!);
    }
    return false;
  }

  // Copy with method for updates
  RaceChallenge copyWith({
    String? challengeId,
    String? clubId,
    String? creatorId,
    String? creatorDisplayName,
    ChallengeType? type,
    DateTime? scheduledTime,
    int? maxParticipants,
    int? questionsCount,
    List<String>? participantIds,
    ChallengeStatus? status,
    DateTime? createdAt,
    String? roomCode,
  }) {
    return RaceChallenge(
      challengeId: challengeId ?? this.challengeId,
      clubId: clubId ?? this.clubId,
      creatorId: creatorId ?? this.creatorId,
      creatorDisplayName: creatorDisplayName ?? this.creatorDisplayName,
      type: type ?? this.type,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      questionsCount: questionsCount ?? this.questionsCount,
      participantIds: participantIds ?? this.participantIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      roomCode: roomCode ?? this.roomCode,
    );
  }
}
