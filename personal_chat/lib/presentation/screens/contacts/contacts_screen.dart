import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../chat/chat_screen.dart';
import '../../widgets/user_avatar.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Contacts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              // Navigate to search to add contacts
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, ChatProvider>(
        builder: (context, authProvider, chatProvider, child) {
          if (chatProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get unique contacts from chats
          final contacts = <dynamic>[];
          for (final chat in chatProvider.chats) {
            if (chat.participant != null) {
              contacts.add(chat.participant);
            }
          }

          if (contacts.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                onTap: () async {
                  final chat = await chatProvider.startChat(
                    authProvider.currentUser!.id,
                    contact,
                  );
                  if (chat != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(chat: chat),
                      ),
                    );
                  }
                },
                leading: UserAvatar(
                  photoUrl: contact.photoUrl,
                  username: contact.username,
                  radius: 24,
                  fontSize: 18,
                  showOnlineStatus: true,
                  isOnline: contact.isOnline,
                ),
                title: Text(
                  contact.username,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  contact.userId,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.chat_bubble_outline),
                  onPressed: () async {
                    final chat = await chatProvider.startChat(
                      authProvider.currentUser!.id,
                      contact,
                    );
                    if (chat != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(chat: chat),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for users to add as contacts',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
