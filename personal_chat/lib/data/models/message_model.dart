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
  final bool isEdited;
  final Map<String, String>? reactions;
  final String? fileName; // For document messages
  final int? fileSize; // For document messages (bytes)
  final int? audioDuration; // For audio messages (seconds)
  final DateTime? deliveredAt;
  final DateTime? readAt;

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
    this.isEdited = false,
    this.reactions,
    this.fileName,
    this.fileSize,
    this.audioDuration,
    this.deliveredAt,
    this.readAt,
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
      isEdited: map['isEdited'] ?? false,
      reactions: map['reactions'] != null ? Map<String, String>.from(map['reactions']) : null,
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      audioDuration: map['audioDuration'],
      deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
      readAt: map['readAt'] != null ? DateTime.parse(map['readAt']) : null,
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
      'isEdited': isEdited,
      'reactions': reactions,
      'fileName': fileName,
      'fileSize': fileSize,
      'audioDuration': audioDuration,
      'deliveredAt': deliveredAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
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
    bool? isEdited,
    Map<String, String>? reactions,
    String? fileName,
    int? fileSize,
    int? audioDuration,
    DateTime? deliveredAt,
    DateTime? readAt,
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
      isEdited: isEdited ?? this.isEdited,
      reactions: reactions ?? this.reactions,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      audioDuration: audioDuration ?? this.audioDuration,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

enum MessageType { text, image, file, audio, location, document }
