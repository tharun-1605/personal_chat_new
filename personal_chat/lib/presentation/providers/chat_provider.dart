import 'package:flutter/foundation.dart';
import '../../data/models/chat_model.dart';
import '../../data/models/message_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/chat_repository.dart';

class ChatProvider extends ChangeNotifier {
  final ChatRepository _chatRepository = ChatRepository();

  List<ChatModel> _chats = [];
  List<MessageModel> _messages = [];
  ChatModel? _currentChat;
  MessageModel? _replyingTo;
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  ChatModel? get currentChat => _currentChat;
  MessageModel? get replyingTo => _replyingTo;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setReplyingTo(MessageModel? message) {
    _replyingTo = message;
    notifyListeners();
  }

  Future<void> loadChats(String currentUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _chats = await _chatRepository.getChats(currentUserId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<List<ChatModel>> getChatsStream(String currentUserId) {
    return _chatRepository.getChatsStream(currentUserId);
  }

  Future<ChatModel?> startChat(
    String currentUserId,
    UserModel participant,
  ) async {
    _isLoading = true;
    notifyListeners();

    try {
      final chat = await _chatRepository.getOrCreateChat(
        currentUserId,
        participant,
      );
      _currentChat = chat;
      if (chat != null && !_chats.any((item) => item.id == chat.id)) {
        _chats.insert(0, chat);
      }
      _isLoading = false;
      notifyListeners();
      return chat;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  void setCurrentChat(ChatModel chat) {
    _currentChat = chat;
    notifyListeners();
  }

  Stream<List<MessageModel>> getMessagesStream(
    String chatId,
    String currentUserId,
  ) {
    final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => _currentChat!);
    return _chatRepository.getMessagesStream(
      chatId, 
      currentUserId,
      clearedAt: chat.clearedAt[currentUserId],
    );
  }

  Future<void> loadMessages(String chatId, String currentUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => _currentChat!);
      _messages = await _chatRepository.getMessages(
        chatId,
        currentUserId: currentUserId,
        clearedAt: chat.clearedAt[currentUserId],
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      await _chatRepository.sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        type: type,
        replyToId: _replyingTo?.id,
        replyToContent: _replyingTo != null ? decryptMessage(_replyingTo!, senderId) : null,
        fileName: fileName,
        fileSize: fileSize,
      );
      _replyingTo = null;
      _chats = await _chatRepository.getChats(senderId);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  String decryptMessage(MessageModel message, String currentUserId) {
    return _chatRepository.decryptMessage(message, currentUserId);
  }

  Future<void> markAsRead(String chatId, String currentUserId) async {
    try {
      await _chatRepository.markMessagesAsRead(chatId, currentUserId);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> markAsDelivered(String messageId) async {
    try {
      await _chatRepository.markMessageAsDelivered(messageId);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> updateTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _chatRepository.updateTypingStatus(chatId, userId, isTyping);
    } catch (e) {
      // Ignore typing status update errors silently to avoid spamming UI
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      await _chatRepository.deleteChat(chatId);
      _chats.removeWhere((chat) => chat.id == chatId);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> clearChat(String chatId, String currentUserId) async {
    try {
      await _chatRepository.clearChat(chatId, currentUserId);
      _messages = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _chatRepository.deleteMessageForEveryone(messageId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleReaction(String messageId, String emoji, String currentUserId) async {
    try {
      await _chatRepository.toggleReaction(messageId, emoji, currentUserId);
    } catch (e) {
      // Ignore reaction errors to avoid spamming UI
    }
  }

  Future<void> clearCurrentChat() async {}

  Future<void> editMessage(String messageId, String newContent, String currentUserId, String otherUserId) async {
    try {
      final encrypted = _chatRepository.encryptForEdit(newContent, currentUserId, otherUserId);
      await _chatRepository.editMessage(messageId, encrypted);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> setDisappearingMessages(String chatId, String mode) async {
    try {
      await _chatRepository.setDisappearingMessages(chatId, mode);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> togglePinChat(String chatId, String userId, bool isPinned) async {
    try {
      await _chatRepository.togglePinChat(chatId, userId, isPinned);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  Future<void> setWallpaper(String chatId, String? color) async {
    try {
      await _chatRepository.setWallpaper(chatId, color);
    } catch (e) {
      _errorMessage = e.toString();
    }
  }
}
