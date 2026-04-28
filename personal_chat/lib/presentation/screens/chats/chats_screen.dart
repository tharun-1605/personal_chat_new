import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../../widgets/user_avatar.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Consumer2<AuthProvider, ChatProvider>(
        builder: (context, authProvider, chatProvider, child) {
          final currentUser = authProvider.currentUser;

          if (currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder(
            stream: chatProvider.getChatsStream(currentUser.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Unable to load chats',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final chats = snapshot.data!;

              if (chats.isEmpty) {
                return _buildEmptyState(context);
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await chatProvider.loadChats(currentUser.id);
                },
                child: ListView.builder(
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];
                    final participant = chat.participant;
                    final unreadCount =
                        chat.unreadCounts[currentUser.id] ?? chat.unreadCount;

                    if (participant == null) return const SizedBox.shrink();

                    return _ChatTile(
                      username: participant.username,
                      userId: participant.userId,
                      lastMessage: chat.lastMessage,
                      time: chat.lastMessageTime,
                      unreadCount: unreadCount,
                      isOnline: participant.isOnline,
                      photoUrl: participant.photoUrl,
                      onTap: () {
                        chatProvider.markAsRead(chat.id, currentUser.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(chat: chat),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to search to start new chat
          // This will be handled by the bottom navigation
        },
        child: const Icon(Icons.edit),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for users to start chatting',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String username;
  final String userId;
  final String lastMessage;
  final DateTime time;
  final int unreadCount;
  final bool isOnline;
  final String? photoUrl;
  final VoidCallback onTap;

  const _ChatTile({
    required this.username,
    required this.userId,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.photoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: UserAvatar(
        photoUrl: photoUrl,
        username: username,
        radius: 28,
        fontSize: 20,
        showOnlineStatus: true,
        isOnline: isOnline,
      ),
      title: Text(
        username,
        style: TextStyle(
          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        lastMessage.isEmpty ? 'Start a conversation' : lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: hasUnread
              ? Theme.of(context).colorScheme.onSurface
              : (lastMessage.isEmpty ? Colors.grey[500] : Colors.grey[600]),
          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(time),
            style: TextStyle(
              fontSize: 12,
              color: hasUnread ? AppTheme.successColor : Colors.grey[500],
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          if (hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }
}
