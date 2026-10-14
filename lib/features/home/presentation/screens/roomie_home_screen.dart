import 'package:flutter/material.dart';

import '../pages/favorites_page.dart';
import '../pages/profile_page.dart';
import '../pages/roomie_home_page.dart';
import '../pages/roomies_page.dart';
import '../pages/search_page.dart';

class RoomieHomeScreen extends StatefulWidget {
  const RoomieHomeScreen({super.key});

  @override
  State<RoomieHomeScreen> createState() => _RoomieHomeScreenState();
}

class _RoomieHomeScreenState extends State<RoomieHomeScreen> {
  int currentIndex = 0;

  final pages = const [
    RoomieHomePage(),
    SearchPage(),
    RoomiesPage(),
    FavoritesPage(),
    ProfilePage(),
  ];

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
            icon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Roomies',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
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