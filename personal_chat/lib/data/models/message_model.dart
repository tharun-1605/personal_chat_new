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
  final String? replyToId;
  final String? replyToContent; // Encrypted
  final bool isDeleted;
  final Map<String, String>? reactions;

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
    this.replyToId,
    this.replyToContent,
    this.isDeleted = false,
    this.reactions,
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
      replyToId: map['replyToId'],
      replyToContent: map['replyToContent'],
      isDeleted: map['isDeleted'] ?? false,
      reactions: map['reactions'] != null ? Map<String, String>.from(map['reactions']) : null,
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
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'isDeleted': isDeleted,
      'reactions': reactions,
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
    String? replyToId,
    String? replyToContent,
    bool? isDeleted,
    Map<String, String>? reactions,
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
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      isDeleted: isDeleted ?? this.isDeleted,
      reactions: reactions ?? this.reactions,
    );
  }
}

enum MessageType { text, image, file }
