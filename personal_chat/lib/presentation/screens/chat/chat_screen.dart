import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/user_avatar.dart';
import 'message_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatScreen({super.key, required this.chat});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Voice recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

  Timer? _typingTimer;
  Stream<List<MessageModel>>? _messagesStream;

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) return 'Today';
    if (targetDate == yesterday) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMessages();
        final currentUser = context.read<AuthProvider>().currentUser;
        if (currentUser != null) {
          setState(() {
            _messagesStream = context.read<ChatProvider>().getMessagesStream(widget.chat.id, currentUser.id);
          });
        }
      }
    });
    _messageController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final chatProvider = context.read<ChatProvider>();
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser != null) {
      if (_typingTimer?.isActive ?? false) _typingTimer!.cancel();
      
      chatProvider.updateTypingStatus(
        widget.chat.id,
        currentUser.id,
        _messageController.text.isNotEmpty,
      );
      
      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          chatProvider.updateTypingStatus(
            widget.chat.id,
            currentUser.id,
            false,
          );
        }
      });
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

  String _formatLastSeen(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final targetDate = DateTime(time.year, time.month, time.day);

    final timeString = DateFormat('h:mm a').format(time);

    if (targetDate == today) {
      return 'last seen today at $timeString';
    } else if (targetDate == yesterday) {
      return 'last seen yesterday at $timeString';
    } else {
      return 'last seen ${DateFormat('MMM d').format(time)} at $timeString';
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _typingTimer?.cancel();
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
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image == null) return;
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;
    final chatId = widget.chat.id;
    final receiverId = widget.chat.participantId;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending image...')));

    try {
      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);
      final url = 'data:image/jpeg;base64,$base64Image';
      await chatProvider.sendMessage(
        chatId: chatId,
        senderId: currentUser.id,
        receiverId: receiverId,
        content: url,
        type: MessageType.image,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send image: $e')));
    }
  }

  Future<void> _pickAndSendDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    final file = result.files.first;
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending document...')));

    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final base64Doc = base64Encode(bytes);
      await chatProvider.sendMessage(
        chatId: widget.chat.id,
        senderId: currentUser.id,
        receiverId: widget.chat.participantId,
        content: 'data:application/octet-stream;base64,$base64Doc',
        type: MessageType.document,
        fileName: file.name,
        fileSize: file.size,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send document: $e')));
    }
  }

  Future<void> _sendLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Getting location...')));
      
      final position = await Geolocator.getCurrentPosition();
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final currentUser = authProvider.currentUser;
      if (currentUser == null) return;

      await chatProvider.sendMessage(
        chatId: widget.chat.id,
        senderId: currentUser.id,
        receiverId: widget.chat.participantId,
        content: '${position.latitude},${position.longitude}',
        type: MessageType.location,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _audioRecorder.hasPermission();
    if (!hasPermission) return;
    final path = '${Directory.systemTemp.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(), path: path);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopAndSendRecording() async {
    final path = await _audioRecorder.stop();
    setState(() { _isRecording = false; });
    if (path == null || !mounted) return;

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();
    final currentUser = authProvider.currentUser;
    if (currentUser == null) return;

    try {
      final bytes = await File(path).readAsBytes();
      final base64Audio = base64Encode(bytes);
      await chatProvider.sendMessage(
        chatId: widget.chat.id,
        senderId: currentUser.id,
        receiverId: widget.chat.participantId,
        content: 'data:audio/m4a;base64,$base64Audio',
        type: MessageType.audio,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send audio: $e')));
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 20,
            runSpacing: 20,
            children: [
              _AttachOption(icon: Icons.image, label: 'Gallery', color: Colors.purple, onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              }),
              _AttachOption(icon: Icons.insert_drive_file, label: 'Document', color: Colors.blue, onTap: () {
                Navigator.pop(context);
                _pickAndSendDocument();
              }),
              _AttachOption(icon: Icons.location_on, label: 'Location', color: Colors.green, onTap: () {
                Navigator.pop(context);
                _sendLocation();
              }),
              _AttachOption(icon: Icons.camera_alt, label: 'Camera', color: Colors.orange, onTap: () {
                Navigator.pop(context);
                ImagePicker().pickImage(source: ImageSource.camera).then((image) async {
                  if (image == null || !mounted) return;
                  final currentUser = context.read<AuthProvider>().currentUser;
                  if (currentUser == null) return;
                  final bytes = await File(image.path).readAsBytes();
                  final base64Image = base64Encode(bytes);
                  await context.read<ChatProvider>().sendMessage(
                    chatId: widget.chat.id,
                    senderId: currentUser.id,
                    receiverId: widget.chat.participantId,
                    content: 'data:image/jpeg;base64,$base64Image',
                    type: MessageType.image,
                  );
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.chat.participant;
    final currentUser = context.read<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: _isSearching ? 48 : 72,
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              )
            : InkWell(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_back, size: 24),
                    const SizedBox(width: 2),
                    UserAvatar(
                      photoUrl: participant?.photoUrl,
                      username: participant?.username ?? '',
                      radius: 18,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              )
            : Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  final currentChat = chatProvider.chats.firstWhere(
                    (c) => c.id == widget.chat.id,
                    orElse: () => widget.chat,
                  );
                  final isTyping = currentChat.typingStatus[participant?.id ?? ''] == true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        participant?.username ?? 'Unknown',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        isTyping 
                            ? 'typing...' 
                            : (participant?.isOnline == true 
                                ? 'Online' 
                                : _formatLastSeen(participant?.lastSeen ?? DateTime.now())),
                        style: TextStyle(
                          fontSize: 12,
                          color: isTyping || participant?.isOnline == true
                              ? Colors.greenAccent
                              : Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  );
                },
              ),
        actions: [
          if (!_isSearching)
            IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          if (!_isSearching)
            IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear Chat'),
                    content: const Text('Are you sure you want to clear this chat?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<ChatProvider>().clearChat(widget.chat.id, currentUser!.id);
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              } else if (value == 'disappear') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Disappearing Messages'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: ['off', '24h', '7days'].map((mode) =>
                        ListTile(
                          title: Text(mode == 'off' ? 'Off' : mode == '24h' ? '24 Hours' : '7 Days'),
                          leading: Radio<String>(
                            value: mode,
                            groupValue: widget.chat.disappearingMode,
                            onChanged: (val) {
                              Navigator.pop(context);
                              if (val != null) context.read<ChatProvider>().setDisappearingMessages(widget.chat.id, val);
                            },
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            context.read<ChatProvider>().setDisappearingMessages(widget.chat.id, mode);
                          },
                        ),
                      ).toList(),
                    ),
                  ),
                );
              } else if (value == 'wallpaper') {
                final colors = [
                  null, '#EFEAe2', '#D5E8D4', '#DAE8FC', '#FFE6CC', '#F8CECC',
                  '#E1D5E7', '#FFF2CC', '#0B141A',
                ];
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Chat Wallpaper'),
                    content: Wrap(
                      spacing: 10,
                      children: colors.map((color) =>
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            context.read<ChatProvider>().setWallpaper(widget.chat.id, color);
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color == null ? null : Color(int.parse('0xFF${color.replaceAll('#', '')}', radix: 16)),
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              gradient: color == null ? const LinearGradient(colors: [Colors.grey, Colors.white]) : null,
                            ),
                            child: color == null ? const Icon(Icons.cancel, size: 18, color: Colors.grey) : null,
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'disappear', child: Text('Disappearing messages')),
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
            ],
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final wallpaperColor = widget.chat.wallpaperColor;
          Color? bgColor;
          if (wallpaperColor != null) {
            try {
              bgColor = Color(int.parse('0xFF${wallpaperColor.replaceAll('#', '')}', radix: 16));
            } catch (_) {}
          }
          return Container(
            color: bgColor,
            child: Column(
              children: [
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
                      if (currentUser == null) {
                        return const Center(child: Text('Please log in again'));
                      }
                      if (_messagesStream == null) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return StreamBuilder(
                        stream: _messagesStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Unable to load messages', style: TextStyle(color: Colors.grey[600])));
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          var filteredMessages = snapshot.data!;
                          if (_isSearching && _searchQuery.isNotEmpty) {
                            filteredMessages = filteredMessages.where((message) {
                              if (message.type != MessageType.text) return false;
                              final decrypted = chatProvider.decryptMessage(message, currentUser.id);
                              return decrypted.toLowerCase().contains(_searchQuery);
                            }).toList();
                          }

                          final undeliveredIncomingMessages = snapshot.data!.where(
                            (m) => m.receiverId == currentUser.id && !m.isDelivered,
                          );
                          if (undeliveredIncomingMessages.isNotEmpty) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                for (final m in undeliveredIncomingMessages) {
                                  chatProvider.markAsDelivered(m.id);
                                }
                              }
                            });
                          }

                          if (filteredMessages.isEmpty) {
                            return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.grey)));
                          }

                          return ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredMessages.length,
                            itemBuilder: (context, index) {
                              final message = filteredMessages[index];
                              final isMe = message.senderId == currentUser.id;
                              final decryptedContent = chatProvider.decryptMessage(message, currentUser.id);
                              String? decryptedReply;
                              if (message.replyToContent != null) {
                                decryptedReply = chatProvider.decryptMessage(
                                  message.copyWith(content: message.replyToContent!),
                                  currentUser.id,
                                );
                              }

                              final messageWidget = Dismissible(
                                key: ValueKey(message.id),
                                direction: DismissDirection.startToEnd,
                                confirmDismiss: (_) async {
                                  chatProvider.setReplyingTo(message);
                                  return false;
                                },
                                background: Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(Icons.reply, color: AppTheme.primaryColor),
                                ),
                                child: GestureDetector(
                                  onLongPress: () {
                                    if (message.isDeleted && !isMe) return;
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: Theme.of(context).cardColor,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      builder: (context) => SafeArea(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!message.isDeleted)
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                                                    return GestureDetector(
                                                      onTap: () {
                                                        Navigator.pop(context);
                                                        chatProvider.toggleReaction(message.id, emoji, currentUser.id);
                                                      },
                                                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                                                    );
                                                  }).toList(),
                                                ),
                                              ),
                                            if (!message.isDeleted) const Divider(height: 1),
                                            if (!message.isDeleted && message.type == MessageType.text)
                                              ListTile(
                                                leading: const Icon(Icons.copy),
                                                title: const Text('Copy Text'),
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: decryptedContent));
                                                  Navigator.pop(context);
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                                                },
                                              ),
                                            if (isMe && !message.isDeleted)
                                              ListTile(
                                                leading: const Icon(Icons.delete, color: Colors.red),
                                                title: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: const Text('Delete Message'),
                                                      content: const Text('Delete this message for everyone?'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                            chatProvider.deleteMessageForEveryone(message.id);
                                                          },
                                                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (isMe && !message.isDeleted && message.type == MessageType.text)
                                              ListTile(
                                                leading: const Icon(Icons.edit),
                                                title: const Text('Edit Message'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  final editController = TextEditingController(text: decryptedContent);
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Edit Message'),
                                                      content: TextField(
                                                        controller: editController,
                                                        autofocus: true,
                                                        maxLines: null,
                                                        decoration: const InputDecoration(border: OutlineInputBorder()),
                                                      ),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            chatProvider.editMessage(
                                                              message.id,
                                                              editController.text,
                                                              currentUser.id,
                                                              widget.chat.participantId,
                                                            );
                                                          },
                                                          child: const Text('Save'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            if (isMe && !message.isDeleted)
                                              ListTile(
                                                leading: const Icon(Icons.info_outline),
                                                title: const Text('Message Info'),
                                                onTap: () {
                                                  Navigator.pop(context);
                                                  Navigator.push(context, MaterialPageRoute(
                                                    builder: (_) => MessageInfoScreen(
                                                      message: message,
                                                      decryptedContent: decryptedContent,
                                                    ),
                                                  ));
                                                },
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                  child: _MessageBubble(
                                    message: message.isDeleted ? '' : decryptedContent,
                                    isMe: isMe,
                                    time: message.timestamp,
                                    isDelivered: message.isDelivered,
                                    isRead: message.isRead,
                                    type: message.type,
                                    isDeleted: message.isDeleted,
                                    isEdited: message.isEdited,
                                    replyToContent: decryptedReply,
                                    reactions: message.reactions,
                                  ),
                                ),
                              );

                              final showDateHeader = !_isSearching && (index == filteredMessages.length - 1 ||
                                  filteredMessages[index].timestamp.day != filteredMessages[index + 1].timestamp.day);

                              if (showDateHeader) {
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.symmetric(vertical: 12),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDateHeader(message.timestamp),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    messageWidget,
                                  ],
                                );
                              }
                              return messageWidget;
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                Consumer<ChatProvider>(
                  builder: (context, provider, child) {
                    if (provider.replyingTo == null) return const SizedBox.shrink();
                    final replyMsg = provider.replyingTo!;
                    final isMyReply = replyMsg.senderId == currentUser?.id;
                    final decryptedReplyTo = provider.decryptMessage(replyMsg, currentUser?.id ?? '');
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.reply, color: AppTheme.primaryColor, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMyReply ? 'You' : widget.chat.participant?.username ?? 'User',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor, fontSize: 13),
                                ),
                                Text(
                                  replyMsg.type == MessageType.image ? '📷 Image' : decryptedReplyTo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => provider.setReplyingTo(null),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: SafeArea(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                                  onPressed: () {},
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    textCapitalization: TextCapitalization.sentences,
                                    maxLines: 6,
                                    minLines: 1,
                                    decoration: const InputDecoration(
                                      hintText: 'Message',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                                  onPressed: _showAttachmentSheet,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _isRecording ? null : _sendMessage,
                          onLongPress: _startRecording,
                          onLongPressEnd: (_) => _stopAndSendRecording(),
                          onLongPressCancel: _stopAndSendRecording,
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.red : AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                _isRecording ? Icons.mic : Icons.send,
                                color: Colors.white, size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
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
  final bool isDeleted;
  final bool isEdited;
  final String? replyToContent;
  final Map<String, String>? reactions;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.time,
    required this.isDelivered,
    required this.isRead,
    this.type = MessageType.text,
    this.isDeleted = false,
    this.isEdited = false,
    this.replyToContent,
    this.reactions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: isMe
                  ? (isDark ? AppTheme.sentMessageColorDark : AppTheme.sentMessageColor)
                  : (isDark ? AppTheme.receivedMessageColorDark : AppTheme.receivedMessageColor),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isMe ? 24 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (replyToContent != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      replyToContent!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                if (isDeleted)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('This message was deleted', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
                    ],
                  )
                else if (type == MessageType.text)
                  Text(message, style: const TextStyle(fontSize: 16))
                else if (type == MessageType.image)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(message.split(',').last),
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                    ),
                  )
                else if (type == MessageType.audio)
                  _AudioBubble(audioUrl: message)
                else if (type == MessageType.document)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.insert_drive_file, color: AppTheme.primaryColor),
                      SizedBox(width: 8),
                      Text('Document'),
                    ],
                  )
                else if (type == MessageType.location)
                  _LocationBubble(location: message),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEdited && !isDeleted)
                      const Text('(Edited) ', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      DateFormat('HH:mm').format(time),
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        isRead ? Icons.done_all : Icons.done,
                        size: 14,
                        color: isRead ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (reactions != null && reactions!.isNotEmpty)
            Positioned(
              bottom: -10,
              right: isMe ? null : -10,
              left: isMe ? -10 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
                ),
                child: Text(reactions!.values.join(' '), style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _AudioBubble extends StatefulWidget {
  final String audioUrl;
  const _AudioBubble({required this.audioUrl});
  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setAudioSource(_Base64AudioSource(widget.audioUrl));
      _player.positionStream.listen((p) => setState(() => _position = p));
      _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _isPlaying = s.playing);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () => _isPlaying ? _player.pause() : _player.play(),
        ),
        Text('${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}'),
        const SizedBox(width: 8),
        const Icon(Icons.mic, color: AppTheme.primaryColor, size: 16),
      ],
    );
  }
}

class _Base64AudioSource extends StreamAudioSource {
  final String base64Data;
  _Base64AudioSource(this.base64Data);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final bytes = base64Decode(base64Data.split(',').last);
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: bytes.length,
      offset: 0,
      contentType: 'audio/m4a',
      stream: Stream.value(bytes),
    );
  }
}

class _LocationBubble extends StatelessWidget {
  final String location;
  const _LocationBubble({required this.location});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on, color: Colors.red),
        const SizedBox(height: 4),
        const Text('Shared Location', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(location, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
