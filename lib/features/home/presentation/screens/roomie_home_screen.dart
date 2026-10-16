import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/screens/roomie_messages_page.dart';
import '../pages/favorites_page.dart';
import '../pages/profile_page.dart';
import '../pages/roomie_home_page.dart';
import '../pages/roomies_page.dart';
import '../pages/search_page.dart';

class RoomieHomeScreen extends StatefulWidget {
  const RoomieHomeScreen({
    super.key,
  });

  @override
  State<RoomieHomeScreen> createState() =>
      _RoomieHomeScreenState();
}

class _RoomieHomeScreenState
    extends State<RoomieHomeScreen> {
  int currentIndex = 0;

  Set<String> favoritePropertyIds = {};

  int unreadMessagesCount = 0;

  String rentalSearchQuery = '';

  StreamSubscription<List<Map<String, dynamic>>>?
      _messagesSubscription;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
    _loadUnreadMessages();
    _listenToMessages();
  }

  Future<void> _loadFavorites() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final data = await supabase
          .from('favorites')
          .select('property_id')
          .eq(
            'user_id',
            user.id,
          );

      final ids = <String>{};

      for (final item in data) {
        final propertyId =
            item['property_id'];

        if (propertyId != null) {
          ids.add(
            propertyId.toString(),
          );
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        favoritePropertyIds = ids;
      });
    } catch (_) {
      // Si falla, dejamos favoritos vacíos.
    }
  }

  Future<void> _loadUnreadMessages() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final conversations = await supabase
          .from('conversations')
          .select('id')
          .eq(
            'roomie_id',
            user.id,
          );

      int total = 0;

      for (final conversation
          in conversations) {
        final conversationId =
            conversation['id']
                ?.toString();

        if (conversationId == null) {
          continue;
        }

        final unreadMessages =
            await supabase
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

        total +=
            unreadMessages.length;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        unreadMessagesCount =
            total;
      });
    } catch (error) {
      debugPrint(
        'ERROR UNREAD MESSAGES: $error',
      );
    }
  }

  void _listenToMessages() {
    final supabase =
        Supabase.instance.client;

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
          'REALTIME UNREAD ERROR: $error',
        );
      },
    );
  }

  Future<void> _toggleFavorite(
    String propertyId,
  ) async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final isFavorite =
        favoritePropertyIds.contains(
      propertyId,
    );

    try {
      if (isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq(
              'user_id',
              user.id,
            )
            .eq(
              'property_id',
              propertyId,
            );
      } else {
        await supabase
            .from('favorites')
            .insert({
          'user_id':
              user.id,
          'property_id':
              propertyId,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        final updatedIds =
            Set<String>.from(
          favoritePropertyIds,
        );

        if (isFavorite) {
          updatedIds.remove(
            propertyId,
          );
        } else {
          updatedIds.add(
            propertyId,
          );
        }

        favoritePropertyIds =
            updatedIds;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.message,
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar el favorito: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  void _goToHome() {
    setState(() {
      currentIndex = 0;
    });
  }

  void _goToRentals() {
    setState(() {
      currentIndex = 1;

      // Si entra manualmente a Alquileres,
      // mostramos todos.
      rentalSearchQuery = '';
    });
  }

  void _searchRentals(
    String query,
  ) {
    final cleanQuery =
        query.trim();

    if (cleanQuery.isEmpty) {
      _goToRentals();
      return;
    }

    setState(() {
      rentalSearchQuery =
          cleanQuery;

      currentIndex = 1;
    });
  }

  void _goToRoomies() {
    setState(() {
      currentIndex = 2;
    });
  }

  void _goToMessages() {
    setState(() {
      currentIndex = 3;
    });

    _loadUnreadMessages();
  }

  void _goToFavorites() {
    setState(() {
      currentIndex = 4;
    });
  }

  void _goToProfile() {
    setState(() {
      currentIndex = 5;
    });
  }

  @override
  void dispose() {
    _messagesSubscription
        ?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final pages = [
      RoomieHomePage(
        favoritePropertyIds:
            favoritePropertyIds,
        onToggleFavorite:
            _toggleFavorite,
        onOpenRentals:
            _goToRentals,
        onOpenRoomies:
            _goToRoomies,
        onSearchRentals:
            _searchRentals,
      ),

      SearchPage(
        key: ValueKey(
          rentalSearchQuery,
        ),
        favoritePropertyIds:
            favoritePropertyIds,
        onToggleFavorite:
            _toggleFavorite,
        initialQuery:
            rentalSearchQuery,
      ),

      const RoomiesPage(),

      const RoomieMessagesPage(),

      FavoritesPage(
        favoritePropertyIds:
            favoritePropertyIds,
        onToggleFavorite:
            _toggleFavorite,
      ),

      const ProfilePage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index:
            currentIndex,
        children:
            pages,
      ),
      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            currentIndex,
        onDestinationSelected:
            (index) {
          switch (index) {
            case 0:
              _goToHome();
              break;

            case 1:
              _goToRentals();
              break;

            case 2:
              _goToRoomies();
              break;

            case 3:
              _goToMessages();
              break;

            case 4:
              _goToFavorites();
              break;

            case 5:
              _goToProfile();
              break;
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.home,
            ),
            label:
                'Inicio',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.apartment_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.apartment,
            ),
            label:
                'Alquileres',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.people_outline,
            ),
            selectedIcon:
                Icon(
              Icons.people,
            ),
            label:
                'Roomies',
          ),

          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  unreadMessagesCount >
                      0,
              child:
                  const Icon(
                Icons
                    .chat_bubble_outline,
              ),
            ),
            selectedIcon:
                Badge(
              isLabelVisible:
                  unreadMessagesCount >
                      0,
              child:
                  const Icon(
                Icons.chat_bubble,
              ),
            ),
            label:
                'Mensajes',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.favorite_border,
            ),
            selectedIcon:
                Icon(
              Icons.favorite,
            ),
            label:
                'Favoritos',
          ),

          const NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(
              Icons.person,
            ),
            label:
                'Perfil',
          ),
        ],
      ),
    );
  }
}