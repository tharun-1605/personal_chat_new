import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/firebase_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/encryption_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../../core/services/notification_service.dart';
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
    String? replyToId,
    String? replyToContent,
    String? fileName,
    int? fileSize,
  }) async {
    final messageId = _uuid.v4();

    // Encrypt the message (even image URLs are encrypted for privacy)
    final encryptedContent = _encryptionService.encryptMessage(
      content,
      senderId,
      receiverId,
    );
    
    String? encryptedReplyContent;
    if (replyToContent != null) {
      encryptedReplyContent = _encryptionService.encryptMessage(
        replyToContent,
        senderId,
        receiverId,
      );
    }

    final message = MessageModel(
      id: messageId,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      participantIds: [senderId, receiverId]..sort(),
      content: encryptedContent,
      timestamp: DateTime.now(),
      type: type,
      replyToId: replyToId,
      replyToContent: encryptedReplyContent,
      fileName: fileName,
      fileSize: fileSize,
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

    // Trigger push notification via standalone backend
    try {
      final receiverDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(receiverId)
          .get();
          
      if (receiverDoc.exists) {
        final receiver = UserModel.fromMap(receiverDoc.data()!);
        if (receiver.fcmToken != null && receiver.fcmToken!.isNotEmpty) {
          final senderDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(senderId)
              .get();
              
          final senderName = senderDoc.exists
              ? UserModel.fromMap(senderDoc.data()!).username
              : 'Someone';
          
          final messageBody = type == MessageType.image ? '📷 Image' : content;

          // Replace with your actual backend URL once deployed (e.g., https://your-app.onrender.com/api/notifications/send)
          // Change this line (around line 197) to use your new Render URL:
final backendUrl = 'https://personal-chat-new.onrender.com/api/notifications/send';

          
          await http.post(
            Uri.parse(backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': receiver.fcmToken,
              'title': senderName,
              'body': messageBody,
              'chatId': chatId,
            }),
          );
        }
      }
    } catch (e) {
      print('Failed to trigger push notification: $e');
    }
  }

  Stream<List<MessageModel>> getMessagesStream(
    String chatId,
    String currentUserId, {
    DateTime? clearedAt,
  }) {
    var query = _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId);

    if (clearedAt != null) {
      query = query.where('timestamp', isGreaterThan: clearedAt.toIso8601String());
    }

    return query
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
    DateTime? clearedAt,
    int limit = 50,
  }) async {
    var query = _firestore
        .collection(AppConstants.messagesCollection)
        .where('chatId', isEqualTo: chatId);

    if (clearedAt != null) {
      query = query.where('timestamp', isGreaterThan: clearedAt.toIso8601String());
    }

    final messagesSnapshot = await query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return messagesSnapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data()))
        .toList();
  }

  String encryptForEdit(String plainText, String senderId, String receiverId) {
    return _encryptionService.encryptMessage(plainText, senderId, receiverId);
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
    final now = DateTime.now().toIso8601String();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {'isDelivered': true, 'isRead': true, 'deliveredAt': now, 'readAt': now});
    }
    await batch.commit();
  }

  Future<void> markMessageAsDelivered(String messageId) async {
    await _firestore
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .update({'isDelivered': true, 'deliveredAt': DateTime.now().toIso8601String()});
  }

  Future<void> updateTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
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

  Future<void> clearChat(String chatId, String userId) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({
      'clearedAt.$userId': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    await _firestore
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .update({
      'isDeleted': true,
      'content': '',
      'type': MessageType.text.index,
    });
  }

  Future<void> editMessage(String messageId, String newEncryptedContent) async {
    await _firestore
        .collection(AppConstants.messagesCollection)
        .doc(messageId)
        .update({'content': newEncryptedContent, 'isEdited': true});
  }

  Future<void> setDisappearingMessages(String chatId, String mode) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({'disappearingMode': mode});
  }

  Future<void> togglePinChat(String chatId, String userId, bool isPinned) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({
      'pinnedBy': isPinned
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> setWallpaper(String chatId, String? color) async {
    await _firestore
        .collection(AppConstants.chatsCollection)
        .doc(chatId)
        .update({'wallpaperColor': color});
  }

  Future<void> toggleReaction(String messageId, String emoji, String currentUserId) async {
    final docRef = _firestore.collection(AppConstants.messagesCollection).doc(messageId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;
      
      final data = doc.data()!;
      final reactions = Map<String, dynamic>.from(data['reactions'] ?? {});
      
      if (reactions[currentUserId] == emoji) {
        reactions.remove(currentUserId);
      } else {
        reactions[currentUserId] = emoji;
      }
      
      transaction.update(docRef, {'reactions': reactions});
    });
  }
}
