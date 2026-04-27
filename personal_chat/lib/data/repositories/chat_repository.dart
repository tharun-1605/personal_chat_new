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

    final chatDoc = await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .get();

    if (chatDoc.exists) {
      return ChatModel.fromMap(chatDoc.data()!, participant: participant);
    }

    // Create new chat
    final newChat = {
      'id': chatId,
      'participantId': participant.id,
      'lastMessage': '',
      'lastMessageTime': DateTime.now().toIso8601String(),
      'unreadCount': 0,
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
        .orderBy('lastMessageTime', descending: true)
        .get();

    final List<ChatModel> chats = [];

    for (final chatDoc in chatsSnapshot.docs) {
      final chatData = chatDoc.data();
      final participantId = chatData['participantId'];

      // Get participant details
      final participantDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(participantId)
          .get();

      if (participantDoc.exists) {
        final participant = UserModel.fromMap(participantDoc.data()!);
        chats.add(ChatModel.fromMap(chatData, participant: participant));
      }
    }

    return chats;
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
  }) async {
    final messageId = _uuid.v4();

    // Encrypt the message
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
      content: encryptedContent,
      timestamp: DateTime.now(),
    );

    // Save message
    await _firestore
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .set(message.toMap());

    // Update chat with last message
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({
          'lastMessage': content,
          'lastMessageTime': DateTime.now().toIso8601String(),
        });
  }

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data()))
              .toList();
        });
  }

  Future<List<MessageModel>> getMessages(
    String chatId, {
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
      return message.content; // Return encrypted if decryption fails
    }
  }

  Future<void> markMessagesAsRead(String chatId, String currentUserId) async {
    final messages = await _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .where('receiverId', isEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in messages.docs) {
      await doc.reference.update({'isRead': true});
    }

    // Reset unread count
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({'unreadCount': 0});
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
