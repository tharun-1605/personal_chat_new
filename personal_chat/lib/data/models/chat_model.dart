import 'user_model.dart';

class ChatModel {
  final String id;
  final String participantId;
  final List<String> participantIds;
  final UserModel? participant;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;

  ChatModel({
    required this.id,
    required this.participantId,
    required this.participantIds,
    this.participant,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatModel.fromMap(
    Map<String, dynamic> map, {
    UserModel? participant,
  }) {
    return ChatModel(
      id: map['id'] ?? '',
      participantId: map['participantId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? const []),
      participant: participant,
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? DateTime.parse(map['lastMessageTime'])
          : DateTime.now(),
      unreadCount: map['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantId': participantId,
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
    };
  }

  ChatModel copyWith({
    String? id,
    String? participantId,
    List<String>? participantIds,
    UserModel? participant,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      participantIds: participantIds ?? this.participantIds,
      participant: participant ?? this.participant,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
