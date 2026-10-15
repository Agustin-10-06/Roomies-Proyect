import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../properties/presentation/screens/create_property_screen.dart';
import '../pages/owner_home_page.dart';
import '../pages/owner_messages_page.dart';
import '../pages/owner_profile_page.dart';
import '../pages/owner_properties_page.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int currentIndex = 0;

  int unreadMessagesCount = 0;

  StreamSubscription<List<Map<String, dynamic>>>?
      _messagesSubscription;

  final pages = const [
    OwnerHomePage(),
    OwnerPropertiesPage(),
    SizedBox.shrink(),
    OwnerMessagesPage(),
    OwnerProfilePage(),
  ];

  @override
  void initState() {
    super.initState();

    _loadUnreadMessages();
    _listenToMessages();
  }

  Future<void> _loadUnreadMessages() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
      final conversations = await supabase
          .from('conversations')
          .select('id')
          .eq(
            'owner_id',
            user.id,
          );

      int total = 0;

      for (final conversation in conversations) {
        final conversationId =
            conversation['id']?.toString();

        if (conversationId == null) {
          continue;
        }

        final unreadMessages = await supabase
            .from('messages')
            .select('id')
            .eq(
              'conversation_id',
              conversationId,
            )
            .neq(
              'sender_id',
              user.id,
            )
            .isFilter(
              'read_at',
              null,
            );

        total += unreadMessages.length;
      }

      if (!mounted) return;

      setState(() {
        unreadMessagesCount = total;
      });
    } catch (error) {
      debugPrint(
        'ERROR OWNER UNREAD MESSAGES: $error',
      );
    }
  }

  void _listenToMessages() {
    final supabase = Supabase.instance.client;

    _messagesSubscription = supabase
        .from('messages')
        .stream(
          primaryKey: ['id'],
        )
        .listen(
      (_) {
        _loadUnreadMessages();
      },
      onError: (error) {
        debugPrint(
          'REALTIME OWNER UNREAD ERROR: $error',
        );
      },
    );
  }

  Future<void> _openCreateProperty() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePropertyScreen(),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      setState(() {
        currentIndex = 1;
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          if (index == 2) {
            _openCreateProperty();
            return;
          }

          setState(() {
            currentIndex = index;
          });

          _loadUnreadMessages();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon: Icon(
              Icons.home,
            ),
            label: 'Inicio',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.home_work_outlined,
            ),
            selectedIcon: Icon(
              Icons.home_work,
            ),
            label: 'Propiedades',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.add_circle_outline,
            ),
            selectedIcon: Icon(
              Icons.add_circle,
            ),
            label: 'Publicar',
          ),

          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  unreadMessagesCount > 0,
              child: const Icon(
                Icons.chat_bubble_outline,
              ),
            ),
            selectedIcon: Badge(
              isLabelVisible:
                  unreadMessagesCount > 0,
              child: const Icon(
                Icons.chat_bubble,
              ),
            ),
            label: 'Mensajes',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}