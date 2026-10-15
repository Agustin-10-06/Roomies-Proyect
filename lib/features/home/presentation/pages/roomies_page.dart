import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RoomiesPage extends StatefulWidget {
  const RoomiesPage({super.key});

  @override
  State<RoomiesPage> createState() => _RoomiesPageState();
}

class _RoomiesPageState extends State<RoomiesPage> {
  final _searchController = TextEditingController();

  bool isLoading = true;

  List<Map<String, dynamic>> allRoomies = [];
  List<Map<String, dynamic>> filteredRoomies = [];

  @override
  void initState() {
    super.initState();

    _loadRoomies();

    _searchController.addListener(
      _applySearch,
    );
  }

  Future<void> _loadRoomies() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await supabase
          .from('roomie_profiles')
          .select()
          .eq(
            'profile_completed',
            true,
          )
          .eq(
            'looking_for_roomie',
            true,
          )
          .neq(
            'user_id',
            user.id,
          );

      final loaded =
          List<Map<String, dynamic>>.from(
        data,
      );

      final List<Map<String, dynamic>> result = [];

      for (final roomie in loaded) {
        final userId =
            roomie['user_id']?.toString();

        if (userId == null) {
          continue;
        }

        try {
          final publicProfile = await supabase
              .rpc(
                'get_public_profile',
                params: {
                  'profile_id': userId,
                },
              )
              .single();

          roomie['public_profile'] =
              publicProfile;
        } catch (_) {
          roomie['public_profile'] = null;
        }

        result.add(roomie);
      }

      if (!mounted) return;

      setState(() {
        allRoomies = result;
        filteredRoomies = result;
        isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
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

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los Roomies: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  void _applySearch() {
    final query = _searchController.text
        .trim()
        .toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredRoomies =
            List<Map<String, dynamic>>.from(
          allRoomies,
        );
      });

      return;
    }

    final filtered = allRoomies.where(
      (roomie) {
        final publicProfile =
            roomie['public_profile'];

        final name =
            publicProfile?['full_name']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final occupation =
            roomie['occupation']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final zone =
            roomie['preferred_zone']
                    ?.toString()
                    .toLowerCase() ??
                '';

        final bio =
            roomie['bio']
                    ?.toString()
                    .toLowerCase() ??
                '';

        return name.contains(query) ||
            occupation.contains(query) ||
            zone.contains(query) ||
            bio.contains(query);
      },
    ).toList();

    setState(() {
      filteredRoomies = filtered;
    });
  }

  int? _calculateAge(dynamic value) {
    if (value == null) {
      return null;
    }

    final birthDate = DateTime.tryParse(
      value.toString(),
    );

    if (birthDate == null) {
      return null;
    }

    final now = DateTime.now();

    int age =
        now.year - birthDate.year;

    final alreadyHadBirthday =
        now.month > birthDate.month ||
        (now.month == birthDate.month &&
            now.day >= birthDate.day);

    if (!alreadyHadBirthday) {
      age--;
    }

    return age;
  }

  String _formatBudget(
    Map<String, dynamic> roomie,
  ) {
    final min = roomie['budget_min'];
    final max = roomie['budget_max'];

    if (min == null && max == null) {
      return 'Presupuesto sin definir';
    }

    if (min != null && max != null) {
      return '\$$min - \$$max';
    }

    if (min != null) {
      return 'Desde \$$min';
    }

    return 'Hasta \$$max';
  }

  Future<void> _refresh() async {
    setState(() {
      isLoading = true;
    });

    await _loadRoomies();

    _applySearch();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Buscar Roomies',
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  children: [
                    TextField(
                      controller:
                          _searchController,
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Buscar por nombre, ocupación o zona...',
                        prefixIcon:
                            Icon(
                          Icons.search,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Roomies sugeridos',
                            style:
                                AppTextStyles.titleMedium,
                          ),
                        ),

                        Text(
                          '${filteredRoomies.length}',
                          style:
                              AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    if (filteredRoomies.isEmpty)
                      _EmptyRoomies(
                        hasSearch:
                            _searchController
                                .text
                                .trim()
                                .isNotEmpty,
                      )
                    else
                      ...filteredRoomies.map(
                        (roomie) =>
                            _RoomieCard(
                          roomie: roomie,
                          age: _calculateAge(
                            roomie[
                                'birth_date'],
                          ),
                          budget:
                              _formatBudget(
                            roomie,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RoomieCard extends StatelessWidget {
  final Map<String, dynamic> roomie;
  final int? age;
  final String budget;

  const _RoomieCard({
    required this.roomie,
    required this.age,
    required this.budget,
  });

  @override
  Widget build(BuildContext context) {
    final publicProfile =
        roomie['public_profile'];

    final name =
        publicProfile?['full_name']
                ?.toString() ??
            'Roomie';

    final photoUrl =
        roomie['profile_photo_url']
            ?.toString();

    final occupation =
        roomie['occupation']
                ?.toString() ??
            'Sin ocupación';

    final zone =
        roomie['preferred_zone']
                ?.toString() ??
            'Zona sin definir';

    final bio =
        roomie['bio']
                ?.toString() ??
            '';

    final smoker =
        roomie['smoker'] as bool?;

    final hasPets =
        roomie['has_pets'] as bool?;

    final cleanlinessLevel =
        roomie['cleanliness_level'];

    final socialLevel =
        roomie['social_level'];

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: AppColors.surface,
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(
          16,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor:
                      AppColors.surface,
                  backgroundImage:
                      photoUrl != null &&
                              photoUrl.isNotEmpty
                          ? NetworkImage(
                              photoUrl,
                            )
                          : null,
                  child: photoUrl == null ||
                          photoUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 34,
                          color:
                              AppColors.primary,
                        )
                      : null,
                ),

                const SizedBox(
                  width: 14,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        age == null
                            ? name
                            : '$name, $age',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 18,
                          fontWeight:
                              FontWeight.w700,
                          color: AppColors
                              .textPrimary,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        occupation,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            AppTextStyles.bodyMedium,
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            size: 16,
                            color: AppColors
                                .secondary,
                          ),
                          const SizedBox(
                            width: 3,
                          ),
                          Expanded(
                            child: Text(
                              zone,
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  AppTextStyles
                                      .bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                color:
                    AppColors.background,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .payments_outlined,
                    color:
                        AppColors.primary,
                    size: 20,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      budget,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (bio.isNotEmpty) ...[
              const SizedBox(
                height: 14,
              ),

              Text(
                bio,
                maxLines: 3,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    AppTextStyles.bodyMedium,
              ),
            ],

            const SizedBox(
              height: 14,
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (smoker != null)
                  _RoomieTag(
                    icon: Icons
                        .smoking_rooms_outlined,
                    text: smoker
                        ? 'Fuma'
                        : 'No fuma',
                  ),

                if (hasPets != null)
                  _RoomieTag(
                    icon:
                        Icons.pets_outlined,
                    text: hasPets
                        ? 'Tiene mascota'
                        : 'Sin mascotas',
                  ),

                if (cleanlinessLevel !=
                    null)
                  _RoomieTag(
                    icon: Icons
                        .cleaning_services_outlined,
                    text:
                        'Orden $cleanlinessLevel/5',
                  ),

                if (socialLevel != null)
                  _RoomieTag(
                    icon:
                        Icons.groups_outlined,
                    text:
                        'Social $socialLevel/5',
                  ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'En el próximo paso abrimos el perfil completo del Roomie.',
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Ver perfil',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomieTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RoomieTag({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
                AppColors.primary,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            text,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoomies extends StatelessWidget {
  final bool hasSearch;

  const _EmptyRoomies({
    required this.hasSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 70,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline,
            size: 62,
            color:
                AppColors.secondary,
          ),

          const SizedBox(
            height: 16,
          ),

          Text(
            hasSearch
                ? 'No encontramos Roomies con esa búsqueda.'
                : 'Todavía no hay otros Roomies disponibles.',
            textAlign:
                TextAlign.center,
            style:
                AppTextStyles.titleMedium,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            hasSearch
                ? 'Probá buscando otra zona, nombre u ocupación.'
                : 'Cuando otros usuarios completen su perfil y activen "Estoy buscando Roomie", aparecerán acá.',
            textAlign:
                TextAlign.center,
            style:
                AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}