import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/theme_provider.dart';
import '../chat/chat_screen.dart';
import '../../widgets/user_avatar.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  String _filter = 'All'; // 'All', 'Unread', 'Muted'
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search chats...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              )
            : const Text('Chats', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _isSearching = true),
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'dark') {
                context.read<ThemeProvider>().toggleTheme();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'dark',
                child: Row(
                  children: [
                    Icon(
                      context.watch<ThemeProvider>().isDarkMode
                          ? Icons.light_mode
                          : Icons.dark_mode,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(context.watch<ThemeProvider>().isDarkMode
                        ? 'Light Mode'
                        : 'Dark Mode'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final currentUser = authProvider.currentUser;

          if (currentUser == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final chatProvider = Provider.of<ChatProvider>(context, listen: false);

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
                          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(snapshot.error.toString(), textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var chats = snapshot.data!;

              // Apply search
              if (_searchQuery.isNotEmpty) {
                chats = chats.where((chat) {
                  final name = chat.participant?.username.toLowerCase() ?? '';
                  return name.contains(_searchQuery) || 
                    chat.lastMessage.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              // Apply filter
              if (_filter == 'Unread') {
                chats = chats.where((c) => (c.unreadCounts[currentUser.id] ?? c.unreadCount) > 0).toList();
              }

              // Sort: pinned first
              chats.sort((a, b) {
                final aPinned = a.pinnedBy.contains(currentUser.id);
                final bPinned = b.pinnedBy.contains(currentUser.id);
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                return b.lastMessageTime.compareTo(a.lastMessageTime);
              });

              if (chats.isEmpty && _searchQuery.isEmpty && _filter == 'All') {
                return _buildEmptyState(context);
              }

              return Column(
                children: [
                  // Filter chips
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Unread'].map((f) =>
                        Padding(
                          padding: const EdgeInsets.only(right: 8, top: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: _filter == f
                                    ? AppTheme.primaryColor
                                    : Colors.grey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  color: _filter == f ? Colors.white : null,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await chatProvider.loadChats(currentUser.id);
                      },
                      child: ListView.builder(
                        itemCount: chats.isEmpty ? 1 : chats.length,
                        itemBuilder: (context, index) {
                          if (chats.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('No chats match filter', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }
                          final chat = chats[index];
                          final participant = chat.participant;
                          final unreadCount = chat.unreadCounts[currentUser.id] ?? chat.unreadCount;
                          final isPinned = chat.pinnedBy.contains(currentUser.id);

                          if (participant == null) return const SizedBox.shrink();

                          return _ChatTile(
                            username: participant.username,
                            userId: participant.userId,
                            lastMessage: chat.lastMessage,
                            time: chat.lastMessageTime,
                            unreadCount: unreadCount,
                            isOnline: participant.isOnline,
                            photoUrl: participant.photoUrl,
                            isPinned: isPinned,
                            onTap: () {
                              chatProvider.markAsRead(chat.id, currentUser.id);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) => ChatScreen(chat: chat),
                              ));
                            },
                            onLongPress: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (context) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ListTile(
                                        leading: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                                        title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          chatProvider.togglePinChat(chat.id, currentUser.id, isPinned);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete, color: Colors.red),
                                        title: const Text('Delete Chat', style: TextStyle(color: Colors.red)),
                                        onTap: () {
                                          Navigator.pop(context);
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Delete Chat'),
                                              content: const Text('Are you sure you want to delete this chat?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(ctx);
                                                    chatProvider.deleteChat(chat.id);
                                                  },
                                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
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
          Text('No conversations yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Search for users to start chatting', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
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
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChatTile({
    required this.username,
    required this.userId,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.photoUrl,
    this.isPinned = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: UserAvatar(
        photoUrl: photoUrl,
        username: username,
        radius: 28,
        fontSize: 20,
        showOnlineStatus: true,
        isOnline: isOnline,
      ),
      title: Row(
        children: [
          if (isPinned)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.push_pin, size: 14, color: Colors.grey),
            ),
          Expanded(
            child: Text(
              username,
              style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
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
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
