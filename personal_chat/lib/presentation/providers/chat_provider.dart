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
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatModel> get chats => _chats;
  List<MessageModel> get messages => _messages;
  ChatModel? get currentChat => _currentChat;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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

  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return _chatRepository.getMessagesStream(chatId);
  }

  Future<void> loadMessages(String chatId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _messages = await _chatRepository.getMessages(chatId);
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
  }) async {
    try {
      await _chatRepository.sendMessage(
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
      );
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

  void clearCurrentChat() {
    _currentChat = null;
    _messages = [];
    notifyListeners();
  }
}
