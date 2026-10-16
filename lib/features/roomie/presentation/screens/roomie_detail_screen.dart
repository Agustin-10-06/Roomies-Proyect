import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'roomie_verification_screen.dart';

class RoomieDetailScreen extends StatelessWidget {
  final Map<String, dynamic> roomie;

  const RoomieDetailScreen({
    super.key,
    required this.roomie,
  });

  int? _calculateAge() {
    final value = roomie['birth_date'];

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

    final now = DateTime.now();

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

  String _formatBudget() {
    final min =
        roomie['budget_min'];

    final max =
        roomie['budget_max'];

    if (min == null &&
        max == null) {
      return 'Sin definir';
    }

    if (min != null &&
        max != null) {
      return '\$$min - \$$max';
    }

    if (min != null) {
      return 'Desde \$$min';
    }

    return 'Hasta \$$max';
  }

  String _yesNo(
    dynamic value,
  ) {
    if (value == null) {
      return 'Sin definir';
    }

    return value == true
        ? 'Sí'
        : 'No';
  }

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return 'Sin definir';
    }

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return 'Sin definir';
    }

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }

  Future<bool>
      _hasDocumentationLoaded() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    final verification =
        await supabase
            .from(
              'roomie_verifications',
            )
            .select(
              'status',
            )
            .eq(
              'user_id',
              user.id,
            )
            .maybeSingle();

    final status =
        verification?['status']
                ?.toString() ??
            'not_started';

    return status ==
        'approved';
  }

  Future<bool> _ensureDocumentation(
    BuildContext context,
  ) async {
    try {
      final alreadyLoaded =
          await _hasDocumentationLoaded();

      if (alreadyLoaded) {
        return true;
      }

      if (!context.mounted) {
        return false;
      }

      final shouldOpen =
          await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) {
          return AlertDialog(
            title:
                const Text(
              'Documentación necesaria',
            ),
            content:
                const Text(
              'Para conectar con otro Roomie primero tenés que cargar el frente y dorso de tu cédula y una selfie.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    false,
                  );
                },
                child:
                    const Text(
                  'Ahora no',
                ),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    true,
                  );
                },
                child:
                    const Text(
                  'Cargar documentación',
                ),
              ),
            ],
          );
        },
      );

      if (shouldOpen != true) {
        return false;
      }

      if (!context.mounted) {
        return false;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const RoomieVerificationScreen(),
        ),
      );

      if (!context.mounted) {
        return false;
      }

      final loadedAfter =
          await _hasDocumentationLoaded();

      if (!loadedAfter) {
        if (!context.mounted) {
          return false;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Necesitás cargar la documentación antes de conectar con otro Roomie.',
            ),
          ),
        );

        return false;
      }

      return true;
    } on PostgrestException catch (error) {
      if (!context.mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            error.message,
          ),
          backgroundColor:
              AppColors.error,
        ),
      );

      return false;
    } catch (error) {
      if (!context.mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo comprobar tu documentación: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );

      return false;
    }
  }

  Future<void> _sendRequest(
    BuildContext context,
  ) async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final canContinue =
        await _ensureDocumentation(
      context,
    );

    if (!canContinue) {
      return;
    }

    final targetUserId =
        roomie['user_id']
            ?.toString();

    if (targetUserId == null) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo identificar al Roomie.',
          ),
        ),
      );

      return;
    }

    if (targetUserId ==
        user.id) {
      return;
    }

    try {
      final existing =
          await supabase
              .from(
                'roomie_requests',
              )
              .select(
                'id, status',
              )
              .eq(
                'requester_id',
                user.id,
              )
              .eq(
                'target_id',
                targetUserId,
              )
              .maybeSingle();

      if (existing != null) {
        final requestStatus =
            existing['status']
                ?.toString();

        if (requestStatus ==
            'pending') {
          if (!context.mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Ya le enviaste una solicitud a este Roomie.',
              ),
            ),
          );

          return;
        }

        if (requestStatus ==
            'accepted') {
          if (!context.mounted) {
            return;
          }

          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Ya tenés una solicitud aceptada con este Roomie.',
              ),
            ),
          );

          return;
        }

        if (requestStatus ==
            'rejected') {
          await supabase.rpc(
            'retry_roomie_request',
            params: {
              'request_id':
                  existing['id'],
            },
          );
        }
      } else {
        await supabase
            .from(
              'roomie_requests',
            )
            .insert({
          'requester_id':
              user.id,
          'target_id':
              targetUserId,
        });
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            'Solicitud enviada.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } on PostgrestException catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content:
              Text(
            error.message,
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar la solicitud: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

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

    final occupation =
        roomie['occupation']
            ?.toString();

    final bio =
        roomie['bio']
            ?.toString();

    final zone =
        roomie['preferred_zone']
            ?.toString();

    final lifestyle =
        roomie['lifestyle']
            ?.toString();

    final workSchedule =
        roomie['work_schedule']
            ?.toString();

    final cleanliness =
        roomie[
            'cleanliness_level'];

    final social =
        roomie['social_level'];

    final documentationLoaded =
        roomie[
                'documentation_loaded'] ==
            true;

    final age =
        _calculateAge();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Perfil Roomie',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(
            20,
          ),
          children: [
            Center(
              child:
                  CircleAvatar(
                radius: 66,
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
                child: photoUrl ==
                            null ||
                        photoUrl
                            .isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 64,
                        color:
                            AppColors.primary,
                      )
                    : null,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              age == null
                  ? name
                  : '$name, $age',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w800,
                color:
                    AppColors
                        .textPrimary,
              ),
            ),

            if (occupation !=
                    null &&
                occupation
                    .isNotEmpty) ...[
              const SizedBox(
                height: 5,
              ),

              Text(
                occupation,
                textAlign:
                    TextAlign.center,
                style:
                    AppTextStyles
                        .bodyMedium,
              ),
            ],

            if (documentationLoaded) ...[
              const SizedBox(
                height: 12,
              ),

              const Center(
                child:
                    _DocumentationBadge(),
              ),
            ],

            if (zone != null &&
                zone.isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  const Icon(
                    Icons
                        .location_on_outlined,
                    size: 18,
                    color:
                        AppColors.secondary,
                  ),

                  const SizedBox(
                    width: 4,
                  ),

                  Flexible(
                    child: Text(
                      zone,
                      style:
                          AppTextStyles
                              .bodyMedium,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(
              height: 28,
            ),

            if (bio != null &&
                bio.isNotEmpty) ...[
              const _SectionTitle(
                title:
                    'Sobre mí',
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                bio,
                style:
                    AppTextStyles
                        .bodyMedium,
              ),

              const SizedBox(
                height: 28,
              ),
            ],

            const _SectionTitle(
              title:
                  'Qué estoy buscando',
            ),

            const SizedBox(
              height: 12,
            ),

            _InfoCard(
              icon:
                  Icons
                      .payments_outlined,
              title:
                  'Presupuesto',
              value:
                  _formatBudget(),
            ),

            if (zone != null &&
                zone.isNotEmpty)
              _InfoCard(
                icon:
                    Icons
                        .location_on_outlined,
                title:
                    'Zona preferida',
                value:
                    zone,
              ),

            _InfoCard(
              icon:
                  Icons
                      .event_outlined,
              title:
                  'Fecha estimada de mudanza',
              value:
                  _formatDate(
                roomie[
                    'move_in_date'],
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            const _SectionTitle(
              title:
                  'Convivencia',
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _SmallInfoCard(
                    icon:
                        Icons
                            .smoking_rooms_outlined,
                    title:
                        'Fuma',
                    value:
                        _yesNo(
                      roomie[
                          'smoker'],
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      _SmallInfoCard(
                    icon:
                        Icons
                            .pets_outlined,
                    title:
                        'Mascotas',
                    value:
                        _yesNo(
                      roomie[
                          'has_pets'],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            _InfoCard(
              icon:
                  Icons
                      .favorite_outline,
              title:
                  'Acepta convivir con mascotas',
              value:
                  _yesNo(
                roomie[
                    'accepts_pets'],
              ),
            ),

            if (cleanliness !=
                null)
              _InfoCard(
                icon:
                    Icons
                        .cleaning_services_outlined,
                title:
                    'Nivel de orden',
                value:
                    '$cleanliness / 5',
              ),

            if (social != null)
              _InfoCard(
                icon:
                    Icons
                        .groups_outlined,
                title:
                    'Nivel de sociabilidad',
                value:
                    '$social / 5',
              ),

            if (workSchedule !=
                    null &&
                workSchedule
                    .isNotEmpty)
              _InfoCard(
                icon:
                    Icons
                        .schedule_outlined,
                title:
                    'Horario / rutina',
                value:
                    workSchedule,
              ),

            if (lifestyle !=
                    null &&
                lifestyle
                    .isNotEmpty) ...[
              const SizedBox(
                height: 22,
              ),

              const _SectionTitle(
                title:
                    'Estilo de vida',
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                lifestyle,
                style:
                    AppTextStyles
                        .bodyMedium,
              ),
            ],

            const SizedBox(
              height: 34,
            ),

            SizedBox(
              height: 54,
              child:
                  FilledButton.icon(
                onPressed: () {
                  _sendRequest(
                    context,
                  );
                },
                icon:
                    const Icon(
                  Icons
                      .group_add_outlined,
                ),
                label:
                    const Text(
                  'Quiero compartir',
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Para conectar con otro Roomie necesitás tener tu documentación cargada.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 12,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentationBadge
    extends StatelessWidget {
  const _DocumentationBadge();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        border:
            Border.all(
          color:
              AppColors.success,
        ),
      ),
      child:
          const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons
                .check_circle_outline,
            size: 17,
            color:
                AppColors.success,
          ),

          SizedBox(
            width: 6,
          ),

          Text(
            'Documentación cargada',
            style:
                TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors
                      .textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      title,
      style:
          AppTextStyles.titleMedium,
    );
  }
}

class _InfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
                BoxDecoration(
              color:
                  AppColors.background,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              icon,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        AppColors
                            .textSecondary,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    color:
                        AppColors
                            .textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallInfoCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SmallInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 12,
              color:
                  AppColors
                      .textSecondary,
            ),
          ),

          const SizedBox(
            height: 3,
          ),

          Text(
            value,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}