import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/config/firebase_config.dart';
import '../../../core/services/notification_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../chats/chats_screen.dart';
import '../contacts/contacts_screen.dart';
import '../search/search_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _messageSubscription;
  bool _hasLoadedInitialMessageSnapshot = false;

  final List<Widget> _screens = [
    const ChatsScreen(),
    const ContactsScreen(),
    const SearchScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  void _loadInitialData() {
    final authProvider = context.read<AuthProvider>();
    final currentUser = authProvider.currentUser;

    if (currentUser != null) {
      // Load chats
      final chatProvider = context.read<ChatProvider>();
      chatProvider.loadChats(currentUser.id);
      _listenForIncomingMessages(currentUser.id, chatProvider);
    }
  }

  void _listenForIncomingMessages(
    String currentUserId,
    ChatProvider chatProvider,
  ) {
    _messageSubscription?.cancel();
    _hasLoadedInitialMessageSnapshot = false;
    _messageSubscription = FirebaseConfig.firestore
        .collection(AppConstants.messagesCollection)
        .where('receiverId', isEqualTo: currentUserId)
        .snapshots()
        .listen((snapshot) {
          if (!_hasLoadedInitialMessageSnapshot) {
            _hasLoadedInitialMessageSnapshot = true;
            for (final doc in snapshot.docs) {
              final data = doc.data();
              if (data['isDelivered'] != true) {
                chatProvider.markAsDelivered(doc.id);
              }
            }
            return;
          }

          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            final isUnread = data?['isRead'] != true;
            final isUndelivered = data?['isDelivered'] != true;

            if (change.type == DocumentChangeType.added && isUnread) {
              NotificationService().showMessageNotification(
                title: 'New message',
                body: 'You have received a new message.',
                payload: data?['chatId'] as String?,
              );
            }

            if (isUndelivered) {
              chatProvider.markAsDelivered(change.doc.id);
            }
          }
        });
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Chats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.contacts_outlined),
              activeIcon: Icon(Icons.contacts),
              label: 'Contacts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
