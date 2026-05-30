import 'user_model.dart';

class ChatModel {
  final String id;
  final String participantId;
  final List<String> participantIds;
  final UserModel? participant;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingStatus;
  final Map<String, DateTime> clearedAt;
  final String disappearingMode; // 'off', '24h', '7days'
  final List<String> pinnedBy;
  final String? wallpaperColor;

  ChatModel({
    required this.id,
    required this.participantId,
    required this.participantIds,
    this.participant,
    required this.lastMessage,
    required this.lastMessageTime,
    this.unreadCount = 0,
    this.unreadCounts = const {},
    this.typingStatus = const {},
    this.clearedAt = const {},
    this.disappearingMode = 'off',
    this.pinnedBy = const [],
    this.wallpaperColor,
  });

  factory ChatModel.fromMap(
    Map<String, dynamic> map, {
    UserModel? participant,
  }) {
    final unreadCountsMap = Map<String, dynamic>.from(
      map['unreadCounts'] ?? const {},
    );
    final typingStatusMap = Map<String, dynamic>.from(
      map['typingStatus'] ?? const {},
    );
    final clearedAtMap = Map<String, dynamic>.from(
      map['clearedAt'] ?? const {},
    );

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
      unreadCounts: unreadCountsMap.map(
        (key, value) => MapEntry(key, value is int ? value : 0),
      ),
      typingStatus: typingStatusMap.map(
        (key, value) => MapEntry(key, value is bool ? value : false),
      ),
      clearedAt: clearedAtMap.map(
        (key, value) => MapEntry(key, DateTime.parse(value)),
      ),
      disappearingMode: map['disappearingMode'] ?? 'off',
      pinnedBy: List<String>.from(map['pinnedBy'] ?? const []),
      wallpaperColor: map['wallpaperColor'],
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
      'unreadCounts': unreadCounts,
      'typingStatus': typingStatus,
      'clearedAt': clearedAt.map((key, value) => MapEntry(key, value.toIso8601String())),
      'disappearingMode': disappearingMode,
      'pinnedBy': pinnedBy,
      'wallpaperColor': wallpaperColor,
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
    Map<String, int>? unreadCounts,
    Map<String, bool>? typingStatus,
    Map<String, DateTime>? clearedAt,
    String? disappearingMode,
    List<String>? pinnedBy,
    String? wallpaperColor,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participantId: participantId ?? this.participantId,
      participantIds: participantIds ?? this.participantIds,
      participant: participant ?? this.participant,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      typingStatus: typingStatus ?? this.typingStatus,
      clearedAt: clearedAt ?? this.clearedAt,
      disappearingMode: disappearingMode ?? this.disappearingMode,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      wallpaperColor: wallpaperColor ?? this.wallpaperColor,
    );
  }
}
