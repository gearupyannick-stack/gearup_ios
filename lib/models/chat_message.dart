import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  system,
  raceChallenge,
}

class ChatMessage {
  final String messageId;
  final String clubId;
  final String senderId;
  final String senderDisplayName;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.messageId,
    required this.clubId,
    required this.senderId,
    required this.senderDisplayName,
    required this.content,
    required this.type,
    required this.timestamp,
    this.metadata,
  });

  // Convert to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'clubId': clubId,
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'content': content,
      'type': type.name,
      'timestamp': Timestamp.fromDate(timestamp),
      if (metadata != null) 'metadata': metadata,
    };
  }

  // Create from Firestore
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      messageId: doc.id,
      clubId: data['clubId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderDisplayName: data['senderDisplayName'] ?? 'Unknown',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  // Helper getters
  bool get isText => type == MessageType.text;
  bool get isSystem => type == MessageType.system;
  bool get isRaceChallenge => type == MessageType.raceChallenge;

  // Get race challenge ID from metadata
  String? get raceChallengeId => metadata?['raceChallengeId'] as String?;
}
