import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';
import '../../../roomie/presentation/screens/roomie_detail_screen.dart';

class RoomieHomePage extends StatefulWidget {
  final Set<String> favoritePropertyIds;

  final Future<void> Function(
    String propertyId,
  ) onToggleFavorite;

  /// Abre la pestaña Alquileres sin búsqueda.
  final VoidCallback onOpenRentals;

  /// Abre la pestaña Roomies.
  final VoidCallback onOpenRoomies;

  /// Ejecuta una búsqueda desde el Home
  /// y abre Alquileres con ese texto.
  final ValueChanged<String> onSearchRentals;

  const RoomieHomePage({
    super.key,
    required this.favoritePropertyIds,
    required this.onToggleFavorite,
    required this.onOpenRentals,
    required this.onOpenRoomies,
    required this.onSearchRentals,
  });

  @override
  State<RoomieHomePage> createState() =>
      _RoomieHomePageState();
}

class _RoomieHomePageState
    extends State<RoomieHomePage> {
  final TextEditingController
      _searchController =
      TextEditingController();

  String? userName;

  bool isLoadingName = true;
  bool isLoadingProperties = true;
  bool isLoadingRoomies = true;

  List<Map<String, dynamic>> properties = [];
  List<Map<String, dynamic>>
      suggestedRoomies = [];

  StreamSubscription<List<Map<String, dynamic>>>?
      _requestsSubscription;

  @override
  void initState() {
    super.initState();

    _loadUserName();
    _loadProperties();
    _loadSuggestedRoomies();
    _listenToRequests();
  }

  Future<void> _loadUserName() async {
    try {
      final supabase =
          Supabase.instance.client;

      final user =
          supabase.auth.currentUser;

      if (user == null) {
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq(
            'id',
            user.id,
          )
          .single();

      if (!mounted) return;

      setState(() {
        userName =
            profile['full_name']
                ?.toString();
      });
    } catch (_) {
      // Fallback silencioso.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingName = false;
        });
      }
    }
  }

  Future<void> _loadProperties() async {
    try {
      final data =
          await Supabase.instance.client
              .from('properties')
              .select(
                '''
                *,
                property_images (
                  image_url,
                  position
                )
                ''',
              )
              .eq(
                'status',
                'published',
              )
              .order(
                'created_at',
                ascending: false,
              )
              .limit(10);

      if (!mounted) return;

      setState(() {
        properties =
            List<Map<String, dynamic>>
                .from(data);
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

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
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar las propiedades: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingProperties = false;
        });
      }
    }
  }

  Future<void> _loadSuggestedRoomies() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoadingRoomies = false;
        });
      }

      return;
    }

    try {
      final data = await supabase.rpc(
        'get_public_roomies',
      );

      final loaded =
          List<Map<String, dynamic>>
              .from(data);

      final requestResults =
          await Future.wait([
        supabase
            .from('roomie_requests')
            .select(
              'requester_id, target_id, status',
            )
            .eq(
              'requester_id',
              user.id,
            ),
        supabase
            .from('roomie_requests')
            .select(
              'requester_id, target_id, status',
            )
            .eq(
              'target_id',
              user.id,
            ),
      ]);

      final sentRequests =
          List<Map<String, dynamic>>
              .from(
        requestResults[0],
      );

      final receivedRequests =
          List<Map<String, dynamic>>
              .from(
        requestResults[1],
      );

      final hiddenRoomieIds =
          <String>{};

      for (final request
          in sentRequests) {
        final status =
            request['status']
                ?.toString();

        final targetId =
            request['target_id']
                ?.toString();

        if (targetId == null) {
          continue;
        }

        if (status == 'pending' ||
            status == 'accepted') {
          hiddenRoomieIds.add(
            targetId,
          );
        }
      }

      for (final request
          in receivedRequests) {
        final status =
            request['status']
                ?.toString();

        final requesterId =
            request['requester_id']
                ?.toString();

        if (requesterId == null) {
          continue;
        }

        if (status == 'pending' ||
            status == 'accepted') {
          hiddenRoomieIds.add(
            requesterId,
          );
        }
      }

      final availableRoomies =
          loaded.where(
        (roomie) {
          final roomieId =
              roomie['user_id']
                  ?.toString();

          if (roomieId == null) {
            return false;
          }

          return !hiddenRoomieIds
              .contains(roomieId);
        },
      ).take(3).toList();

      if (!mounted) return;

      setState(() {
        suggestedRoomies =
            availableRoomies;

        isLoadingRoomies = false;
      });
    } catch (error) {
      debugPrint(
        'ERROR HOME ROOMIES: $error',
      );

      if (!mounted) return;

      setState(() {
        isLoadingRoomies = false;
      });
    }
  }

  void _listenToRequests() {
    final supabase =
        Supabase.instance.client;

    _requestsSubscription = supabase
        .from('roomie_requests')
        .stream(
          primaryKey: ['id'],
        )
        .listen(
      (_) {
        _loadSuggestedRoomies();
      },
      onError: (error) {
        debugPrint(
          'REALTIME HOME ROOMIES ERROR: $error',
        );
      },
    );
  }

  void _submitSearch() {
    final query =
        _searchController.text.trim();

    if (query.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();

    widget.onSearchRentals(
      query,
    );
  }

  int? _calculateAge(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final birthDate =
        DateTime.tryParse(
      value.toString(),
    );

    if (birthDate == null) {
      return null;
    }

    final now =
        DateTime.now();

    int age =
        now.year - birthDate.year;

    final hadBirthday =
        now.month > birthDate.month ||
            (now.month ==
                    birthDate.month &&
                now.day >=
                    birthDate.day);

    if (!hadBirthday) {
      age--;
    }

    return age;
  }

  String _roomieDescription(
    Map<String, dynamic> roomie,
  ) {
    final occupation =
        roomie['occupation']
            ?.toString()
            .trim();

    final zone =
        roomie['preferred_zone']
            ?.toString()
            .trim();

    final bio =
        roomie['bio']
            ?.toString()
            .trim();

    if (occupation != null &&
        occupation.isNotEmpty &&
        zone != null &&
        zone.isNotEmpty) {
      return '$occupation · $zone';
    }

    if (zone != null &&
        zone.isNotEmpty) {
      return 'Busca compartir en $zone.';
    }

    if (occupation != null &&
        occupation.isNotEmpty) {
      return occupation;
    }

    if (bio != null &&
        bio.isNotEmpty) {
      return bio;
    }

    return 'Busca compartir con otro Roomie.';
  }

  Future<void> _openRoomie(
    Map<String, dynamic> roomie,
  ) async {
    final result =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RoomieDetailScreen(
          roomie: roomie,
        ),
      ),
    );

    if (result == true) {
      await _loadSuggestedRoomies();
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadUserName(),
      _loadProperties(),
      _loadSuggestedRoomies(),
    ]);
  }

  @override
  void dispose() {
    _searchController.dispose();

    _requestsSubscription
        ?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final firstName =
        (userName?.trim().isNotEmpty ??
                false)
            ? userName!
                .trim()
                .split(' ')
                .first
            : 'Roomie';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
              _refresh,
          child: SingleChildScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(
              24,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  isLoadingName
                      ? 'Hola 👋'
                      : 'Hola, $firstName 👋',
                  style:
                      AppTextStyles
                          .titleLarge,
                ),

                const SizedBox(
                  height: 8,
                ),

                const Text(
                  '¿Qué estás buscando hoy?',
                  style:
                      AppTextStyles
                          .bodyLarge,
                ),

                const SizedBox(
                  height: 24,
                ),

                TextField(
                  controller:
                      _searchController,
                  textInputAction:
                      TextInputAction.search,
                  onSubmitted: (_) {
                    _submitSearch();
                  },
                  decoration:
                      InputDecoration(
                    hintText:
                        'Buscar alquileres, zonas...',
                    prefixIcon:
                        IconButton(
                      tooltip:
                          'Buscar',
                      onPressed:
                          _submitSearch,
                      icon:
                          const Icon(
                        Icons.search,
                      ),
                    ),
                    suffixIcon:
                        IconButton(
                      tooltip:
                          'Filtros',
                      onPressed:
                          widget.onOpenRentals,
                      icon:
                          const Icon(
                        Icons.tune,
                      ),
                    ),
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      child: Text(
                        'Propiedades recomendadas',
                        style:
                            AppTextStyles
                                .titleMedium,
                        maxLines: 2,
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    TextButton(
                      onPressed:
                          widget
                              .onOpenRentals,
                      child:
                          const Text(
                        'Ver todas',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                if (isLoadingProperties)
                  const SizedBox(
                    height: 315,
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (properties
                    .isEmpty)
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      24,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.white,
                      borderRadius:
                          BorderRadius.circular(
                        20,
                      ),
                    ),
                    child:
                        const Column(
                      children: [
                        Icon(
                          Icons
                              .home_work_outlined,
                          size: 48,
                          color:
                              AppColors.secondary,
                        ),
                        SizedBox(
                          height: 12,
                        ),
                        Text(
                          'Todavía no hay propiedades publicadas.',
                          textAlign:
                              TextAlign.center,
                          style:
                              AppTextStyles
                                  .bodyLarge,
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 315,
                    child:
                        ListView.separated(
                      scrollDirection:
                          Axis.horizontal,
                      itemCount:
                          properties.length,
                      separatorBuilder:
                          (_, __) =>
                              const SizedBox(
                        width: 16,
                      ),
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        final property =
                            properties[
                                index];

                        final propertyId =
                            property['id']
                                .toString();

                        return _PropertyCard(
                          property:
                              property,
                          isFavorite: widget
                              .favoritePropertyIds
                              .contains(
                            propertyId,
                          ),
                          onFavoritePressed:
                              () {
                            widget
                                .onToggleFavorite(
                              propertyId,
                            );
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PropertyDetailScreen(
                                  property:
                                      property,
                                  isFavorite: widget
                                      .favoritePropertyIds
                                      .contains(
                                    propertyId,
                                  ),
                                  onToggleFavorite:
                                      widget
                                          .onToggleFavorite,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(
                  height: 32,
                ),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Roomies sugeridos',
                        style:
                            AppTextStyles
                                .titleMedium,
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    TextButton(
                      onPressed:
                          widget
                              .onOpenRoomies,
                      child:
                          const Text(
                        'Ver todos',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                if (isLoadingRoomies)
                  const SizedBox(
                    height: 100,
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  )
                else if (suggestedRoomies
                    .isEmpty)
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets.all(
                      22,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.white,
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child:
                        const Column(
                      children: [
                        Icon(
                          Icons
                              .people_outline,
                          size: 42,
                          color:
                              AppColors.secondary,
                        ),

                        SizedBox(
                          height: 10,
                        ),

                        Text(
                          'No hay nuevos Roomies sugeridos por ahora.',
                          textAlign:
                              TextAlign.center,
                          style:
                              AppTextStyles
                                  .bodyLarge,
                        ),
                      ],
                    ),
                  )
                else
                  ...suggestedRoomies
                      .map(
                    (roomie) {
                      final age =
                          _calculateAge(
                        roomie[
                            'birth_date'],
                      );

                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child:
                            _RoomieCard(
                          roomie:
                              roomie,
                          age:
                              age,
                          description:
                              _roomieDescription(
                            roomie,
                          ),
                          onTap: () {
                            _openRoomie(
                              roomie,
                            );
                          },
                        ),
                      );
                    },
                  ),

                const SizedBox(
                  height: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard
    extends StatelessWidget {
  final Map<String, dynamic>
      property;

  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback
      onFavoritePressed;

  const _PropertyCard({
    required this.property,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoritePressed,
  });

  String? _getMainImageUrl() {
    final rawImages =
        property['property_images'];

    if (rawImages == null ||
        rawImages is! List ||
        rawImages.isEmpty) {
      return null;
    }

    final images =
        List<Map<String, dynamic>>
            .from(
      rawImages,
    );

    images.sort(
      (a, b) {
        final aPosition =
            a['position']
                    as int? ??
                0;

        final bPosition =
            b['position']
                    as int? ??
                0;

        return aPosition
            .compareTo(
          bPosition,
        );
      },
    );

    final url =
        images.first['image_url'];

    if (url == null ||
        url
            .toString()
            .trim()
            .isEmpty) {
      return null;
    }

    return url.toString();
  }

  String _propertyTypeLabel() {
    switch (property['property_type']
        ?.toString()) {
      case 'apartment':
        return 'Apartamento';

      case 'house':
        return 'Casa';

      case 'room':
        return 'Habitación';

      case 'studio':
        return 'Monoambiente';

      case 'penthouse':
        return 'Penthouse';

      default:
        return '';
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final imageUrl =
        _getMainImageUrl();

    final typeLabel =
        _propertyTypeLabel();

    final neighborhood =
        property['neighborhood'];

    final city =
        property['city'];

    String location = '';

    if (neighborhood != null &&
        neighborhood
            .toString()
            .trim()
            .isNotEmpty) {
      location =
          neighborhood.toString();
    }

    if (city != null &&
        city
            .toString()
            .trim()
            .isNotEmpty) {
      if (location.isNotEmpty) {
        location += ', ';
      }

      location +=
          city.toString();
    }

    final currency =
        property['currency'] ??
            'UYU';

    final price =
        property['price'] ?? 0;

    return GestureDetector(
      onTap:
          onTap,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color:
              AppColors.white,
          borderRadius:
              BorderRadius.circular(
            22,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(
                alpha: 0.05,
              ),
              blurRadius: 14,
              offset:
                  const Offset(
                0,
                6,
              ),
            ),
          ],
        ),
        clipBehavior:
            Clip.antiAlias,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height:
                      160,
                  width:
                      double.infinity,
                  child: imageUrl ==
                          null
                      ? Container(
                          color:
                              AppColors.surface,
                          child:
                              const Center(
                            child:
                                Icon(
                              Icons
                                  .apartment_rounded,
                              size:
                                  64,
                              color:
                                  AppColors.primary,
                            ),
                          ),
                        )
                      : Image.network(
                          imageUrl,
                          fit:
                              BoxFit.cover,
                          errorBuilder:
                              (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return Container(
                              color:
                                  AppColors.surface,
                              child:
                                  const Center(
                                child:
                                    Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size:
                                      52,
                                  color:
                                      AppColors.secondary,
                                ),
                              ),
                            );
                          },
                        ),
                ),

                if (typeLabel
                    .isNotEmpty)
                  Positioned(
                    left:
                        12,
                    top:
                        12,
                    child:
                        Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal:
                            10,
                        vertical:
                            6,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.white,
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                      child:
                          Text(
                        typeLabel,
                        style:
                            const TextStyle(
                          fontSize:
                              12,
                          fontWeight:
                              FontWeight.w600,
                          color:
                              AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top:
                      12,
                  right:
                      12,
                  child:
                      Container(
                    decoration:
                        const BoxDecoration(
                      color:
                          AppColors.white,
                      shape:
                          BoxShape.circle,
                    ),
                    child:
                        IconButton(
                      onPressed:
                          onFavoritePressed,
                      icon:
                          Icon(
                        isFavorite
                            ? Icons.favorite
                            : Icons
                                .favorite_border,
                        color:
                            AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      property[
                              'title'] ??
                          'Sin título',
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    if (location
                        .isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            size:
                                18,
                            color:
                                AppColors.textSecondary,
                          ),

                          const SizedBox(
                            width:
                                4,
                          ),

                          Expanded(
                            child:
                                Text(
                              location,
                              maxLines:
                                  1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),

                    const Spacer(),

                    Text(
                      '$currency $price / mes',
                      style:
                          const TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.primary,
                      ),
                    ),

                    const SizedBox(
                      height:
                          10,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .bed_outlined,
                          size:
                              18,
                          color:
                              AppColors.textSecondary,
                        ),

                        const SizedBox(
                          width:
                              4,
                        ),

                        Text(
                          '${property['bedrooms'] ?? 0}',
                        ),

                        const SizedBox(
                          width:
                              16,
                        ),

                        const Icon(
                          Icons
                              .bathtub_outlined,
                          size:
                              18,
                          color:
                              AppColors.textSecondary,
                        ),

                        const SizedBox(
                          width:
                              4,
                        ),

                        Text(
                          '${property['bathrooms'] ?? 0}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomieCard
    extends StatelessWidget {
  final Map<String, dynamic>
      roomie;

  final int? age;
  final String description;
  final VoidCallback onTap;

  const _RoomieCard({
    required this.roomie,
    required this.age,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final name =
        roomie['full_name']
                ?.toString() ??
            'Roomie';

    final photoUrl =
        roomie['profile_photo_url']
            ?.toString();

    return Material(
      color:
          AppColors.white,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius:
                    28,
                backgroundColor:
                    AppColors.surface,
                backgroundImage:
                    photoUrl != null &&
                            photoUrl
                                .isNotEmpty
                        ? NetworkImage(
                            photoUrl,
                          )
                        : null,
                child: photoUrl == null ||
                        photoUrl.isEmpty
                    ? const Icon(
                        Icons.person,
                        color:
                            AppColors.primary,
                      )
                    : null,
              ),

              const SizedBox(
                width:
                    16,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      age == null
                          ? name
                          : '$name, $age',
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                        fontSize:
                            16,
                      ),
                    ),

                    const SizedBox(
                      height:
                          4,
                    ),

                    Text(
                      description,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width:
                    8,
              ),

              const Icon(
                Icons.chevron_right,
                color:
                    AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}