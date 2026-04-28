import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessages();
      }
    });
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final chatProvider = context.read<ChatProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      chatProvider.updateTypingStatus(
        widget.chat.id,
        currentUser.id,
        _messageController.text.isNotEmpty,
      );
    }
  }

  void _loadMessages() {
    final chatProvider = context.read<ChatProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    chatProvider.setCurrentChat(widget.chat);
    if (currentUser != null) {
      chatProvider.markAsRead(widget.chat.id, currentUser.id);
      chatProvider.loadMessages(widget.chat.id, currentUser.id);
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    _messageController.clear();

    await chatProvider.sendMessage(
      chatId: widget.chat.id,
      senderId: currentUser.id,
      receiverId: widget.chat.participantId,
      content: message,
      type: MessageType.text,
    );
  }

  Future<void> _pickAndSendImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;
    final chatId = widget.chat.id;
    final receiverId = widget.chat.participantId;

    // Show a loading indicator while uploading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Sending image...')));

    try {
      final file = File(image.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(chatId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();

      await chatProvider.sendMessage(
        chatId: chatId,
        senderId: currentUser.id,
        receiverId: receiverId,
        content: url,
        type: MessageType.image,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.chat.participant;
    final currentUser = context.read<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primaryColor,
                  backgroundImage: participant?.photoUrl != null
                      ? NetworkImage(participant!.photoUrl!)
                      : null,
                  child: participant?.photoUrl == null
                      ? Text(
                          participant?.username.isNotEmpty == true
                              ? participant!.username[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (participant?.isOnline == true)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final currentChat = chatProvider.chats.firstWhere(
                    (c) => c.id == widget.chat.id,
                    orElse: () => widget.chat,
                  );
                  final isTyping =
                      currentChat.typingStatus[participant?.id ?? ''] == true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant?.username ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isTyping ? 'typing...' : (participant?.userId ?? ''),
                        style: TextStyle(
                          fontSize: 12,
                          color: isTyping
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.8),
                          fontStyle: isTyping
                              ? FontStyle.italic
                              : FontStyle.normal,
                          fontWeight: isTyping
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, child) {
                if (chatProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (currentUser == null) {
                  return const Center(child: Text('Please log in again'));
                }

                return StreamBuilder(
                  stream: chatProvider.getMessagesStream(
                    widget.chat.id,
                    currentUser.id,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Unable to load messages',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!;
                    final undeliveredIncomingMessages = messages.where(
                      (message) =>
                          message.receiverId == currentUser.id &&
                          !message.isDelivered,
                    );
                    final hasUnreadIncomingMessage = messages.any(
                      (message) =>
                          message.receiverId == currentUser.id &&
                          !message.isRead,
                    );

                    if (undeliveredIncomingMessages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        for (final message in undeliveredIncomingMessages) {
                          chatProvider.markAsDelivered(message.id);
                        }
                      });
                    }

                    if (hasUnreadIncomingMessage) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          chatProvider.markAsRead(
                            widget.chat.id,
                            currentUser.id,
                          );
                        }
                      });
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 60,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send a message to start the conversation',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == currentUser.id;

                        final decryptedContent = chatProvider.decryptMessage(
                          message,
                          currentUser.id,
                        );

                        return _MessageBubble(
                          message: decryptedContent,
                          isMe: isMe,
                          time: message.timestamp,
                          isDelivered: message.isDelivered,
                          isRead: message.isRead,
                          type: message.type,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Message Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: Colors.grey),
                    onPressed: _pickAndSendImage,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String message;
  final bool isMe;
  final DateTime time;
  final bool isDelivered;
  final bool isRead;
  final MessageType type;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    required this.isDelivered,
    required this.isRead,
    this.type = MessageType.text,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? (isDark
                    ? AppTheme.sentMessageColorDark
                    : AppTheme.sentMessageColor)
              : (isDark
                    ? AppTheme.receivedMessageColorDark
                    : AppTheme.receivedMessageColor),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (type == MessageType.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: message,
                  width: 200,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              )
            else
              Text(
                message,
                style: TextStyle(
                  color: isMe
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(time),
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.7)
                        : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isDelivered || isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
