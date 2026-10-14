import 'package:flutter/material.dart';

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

  final pages = const [
    OwnerHomePage(),
    OwnerPropertiesPage(),
    SizedBox.shrink(),
    OwnerMessagesPage(),
    OwnerProfilePage(),
  ];

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
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_work_outlined),
            selectedIcon: Icon(Icons.home_work),
            label: 'Propiedades',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Publicar',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Mensajes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}