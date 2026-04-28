import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/firebase_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/encryption_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';

class ChatRepository {
  final FirebaseFirestore _firestore = FirebaseConfig.firestore;
  final EncryptionService _encryptionService = EncryptionService();
  final Uuid _uuid = const Uuid();

  String _generateChatId(String userId1, String userId2) {
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<ChatModel?> getOrCreateChat(
    String currentUserId,
    UserModel participant,
  ) async {
    final chatId = _generateChatId(currentUserId, participant.id);
    final participantIds = [currentUserId, participant.id]..sort();

    final chatDoc = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .get();

    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      chatData['participantId'] = participant.id;
      if (chatData['participantIds'] == null) {
        await chatDoc.reference.update({'participantIds': participantIds});
        chatData['participantIds'] = participantIds;
      }
      return ChatModel.fromMap(chatData, participant: participant);
    }

    // Create new chat
    final newChat = {
      'id': chatId,
      'participantId': participant.id,
      'participantIds': participantIds,
      'lastMessage': '',
      'lastMessageTime': DateTime.now().toIso8601String(),
      'unreadCount': 0,
      'unreadCounts': {currentUserId: 0, participant.id: 0},
    };

    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .set(newChat);

    return ChatModel.fromMap(newChat, participant: participant);
  }

  Future<List<ChatModel>> getChats(String currentUserId) async {
    final chatsSnapshot = await _firestore
        .collection(AppConstants.chatsCollection)
        .where('participantIds', arrayContains: currentUserId)
        .get();

    return _buildChatsFromDocs(chatsSnapshot.docs, currentUserId);
  }

  Stream<List<ChatModel>> getChatsStream(String currentUserId) {
    return _firestore
        .collection(AppConstants.chatsCollection)
        .where('participantIds', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) {
          return _buildChatsFromDocs(snapshot.docs, currentUserId);
        });
  }

  Future<List<ChatModel>> _buildChatsFromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String currentUserId,
  ) async {
    final List<ChatModel> chats = [];

    for (final chatDoc in docs) {
      final chatData = chatDoc.data();
      final participantIds = List<String>.from(
        chatData['participantIds'] ?? [],
      );
      final participantId = participantIds.firstWhere(
        (id) => id != currentUserId,
        orElse: () => chatData['participantId'] ?? '',
      );

      if (participantId.isEmpty) continue;

      // Get participant details
      final participantDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(participantId)
          .get();

      if (participantDoc.exists) {
        final participant = UserModel.fromMap(participantDoc.data()!);
        chatData['participantId'] = participantId;
        chats.add(ChatModel.fromMap(chatData, participant: participant));
      }
    }

    chats.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return chats;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final messageId = _uuid.v4();

    // Encrypt the message (even image URLs are encrypted for privacy)
    final encryptedContent = _encryptionService.encryptMessage(
      content,
      senderId,
      receiverId,
    );

    final message = MessageModel(
      id: messageId,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      participantIds: [senderId, receiverId]..sort(),
      content: encryptedContent,
      timestamp: DateTime.now(),
      type: type,
    );

    final chatRef = _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId);

    // Save message
    await _firestore
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .set(message.toMap());

    // Update chat with last message
    await chatRef.update({
      'lastMessage': type == MessageType.image ? '📷 Image' : content,
      'lastMessageTime': DateTime.now().toIso8601String(),
      'participantIds': [senderId, receiverId]..sort(),
      'unreadCounts.$receiverId': FieldValue.increment(1),
      'unreadCounts.$senderId': 0,
      'typingStatus.$senderId': false,
    });
  }

  Stream<List<MessageModel>> getMessagesStream(
    String chatId,
    String currentUserId,
  ) {
    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<List<MessageModel>> getMessages(
    String chatId, {
    required String currentUserId,
    int limit = 50,
  }) async {
    final messagesSnapshot = await _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return messagesSnapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data()))
        .toList();
  }

  String decryptMessage(MessageModel message, String currentUserId) {
    final otherUserId = message.senderId == currentUserId
        ? message.receiverId
        : message.senderId;

    try {
      return _encryptionService.decryptMessage(
        message.content,
        currentUserId,
        otherUserId,
      );
    } catch (e) {
      return 'This older message cannot be decrypted. Please send it again.';
    }
  }

  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({'unreadCount': 0, 'unreadCounts.$currentUserId': 0});

    final messages = await _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    if (messages.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> updateTypingStatus(String chatId, String userId, bool isTyping) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({'typingStatus.$userId': isTyping});
  }

  Future<void> deleteChat(String chatId) async {
    // Delete all messages in the chat
    final messages = await _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .get();

    for (final doc in messages.docs) {
      await doc.reference.delete();
    }

    // Delete chat
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .delete();
  }
}
