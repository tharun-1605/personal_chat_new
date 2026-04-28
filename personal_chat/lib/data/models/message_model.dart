class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final List<String> participantIds;
  final String content; // Encrypted content
  final DateTime timestamp;
  final bool isDelivered;
  final bool isRead;
  final MessageType type;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.participantIds,
    required this.content,
    required this.timestamp,
    this.isDelivered = false,
    this.isRead = false,
    this.type = MessageType.text,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      participantIds: List<String>.from(map['participantIds'] ?? const []),
      content: map['content'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      isDelivered: map['isDelivered'] ?? map['isRead'] ?? false,
      isRead: map['isRead'] ?? false,
      type: MessageType.values[map['type'] ?? 0],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'participantIds': participantIds,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isDelivered': isDelivered,
      'isRead': isRead,
      'type': type.index,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    List<String>? participantIds,
    String? content,
    DateTime? timestamp,
    bool? isDelivered,
    bool? isRead,
    MessageType? type,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      participantIds: participantIds ?? this.participantIds,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}

enum MessageType { text, image, file }
