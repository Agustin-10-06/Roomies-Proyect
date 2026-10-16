import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/screens/welcome_screen.dart';
import '../../../roomie/presentation/screens/complete_roomie_profile_screen.dart';
import '../../../roomie/presentation/screens/roomie_verification_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
  });

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? roomieProfile;

  String verificationStatus = 'not_started';

  @override
  void initState() {
    super.initState();

    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    try {
      final results = await Future.wait([
        supabase
            .from('profiles')
            .select(
              '''
              id,
              full_name,
              role,
              avatar_url
              ''',
            )
            .eq(
              'id',
              user.id,
            )
            .maybeSingle(),

        supabase
            .from(
              'roomie_profiles',
            )
            .select()
            .eq(
              'user_id',
              user.id,
            )
            .maybeSingle(),

        supabase
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
            .maybeSingle(),
      ]);

      if (!mounted) return;

      final profileData =
          results[0];

      final roomieData =
          results[1];

      final verificationData =
          results[2];

      setState(() {
        profile =
            profileData;

        roomieProfile =
            roomieData;

        verificationStatus =
            verificationData?['status']
                    ?.toString() ??
                'not_started';

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el perfil: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  Future<void> _editProfile() async {
    final updated =
        await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CompleteRoomieProfileScreen(),
      ),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  Future<void> _openDocumentation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const RoomieVerificationScreen(),
      ),
    );

    if (!mounted) return;

    await _loadProfile();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const WelcomeScreen(),
      ),
      (route) => false,
    );
  }

  int? _calculateAge() {
    final value =
        roomieProfile?['birth_date']
            ?.toString();

    if (value == null ||
        value.isEmpty) {
      return null;
    }

    final birthDate =
        DateTime.tryParse(
      value,
    );

    if (birthDate == null) {
      return null;
    }

    final now =
        DateTime.now();

    int age =
        now.year - birthDate.year;

    final hadBirthday =
        now.month >
                birthDate.month ||
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
        roomieProfile?['budget_min'];

    final max =
        roomieProfile?['budget_max'];

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

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final name =
        profile?['full_name']
                ?.toString() ??
            'Roomie';

    final photoUrl =
        roomieProfile?[
                'profile_photo_url']
            ?.toString();

    final occupation =
        roomieProfile?['occupation']
            ?.toString();

    final bio =
        roomieProfile?['bio']
            ?.toString();

    final preferredZone =
        roomieProfile?[
                'preferred_zone']
            ?.toString();

    final workSchedule =
        roomieProfile?[
                'work_schedule']
            ?.toString();

    final lifestyle =
        roomieProfile?['lifestyle']
            ?.toString();

    final smoker =
        roomieProfile?['smoker']
            as bool?;

    final hasPets =
        roomieProfile?['has_pets']
            as bool?;

    final acceptsPets =
        roomieProfile?[
                    'accepts_pets']
                as bool? ??
            true;

    final lookingForRoomie =
        roomieProfile?[
                    'looking_for_roomie']
                as bool? ??
            false;

    final profileCompleted =
        roomieProfile?[
                    'profile_completed']
                as bool? ??
            false;

    final cleanlinessLevel =
        roomieProfile?[
            'cleanliness_level'];

    final socialLevel =
        roomieProfile?[
            'social_level'];

    final age =
        _calculateAge();

    final documentationLoaded =
        verificationStatus ==
            'approved';

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Mi perfil',
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
              _loadProfile,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(
              24,
            ),
            children: [
              Center(
                child:
                    CircleAvatar(
                  radius: 58,
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
                          size: 58,
                          color:
                              AppColors.primary,
                        )
                      : null,
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              Text(
                name,
                textAlign:
                    TextAlign.center,
                style:
                    AppTextStyles
                        .titleMedium,
              ),

              if (occupation !=
                      null &&
                  occupation
                      .isNotEmpty) ...[
                const SizedBox(
                  height: 4,
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

              if (age != null) ...[
                const SizedBox(
                  height: 4,
                ),

                Text(
                  '$age años',
                  textAlign:
                      TextAlign.center,
                  style:
                      AppTextStyles
                          .bodyMedium,
                ),
              ],

              const SizedBox(
                height: 16,
              ),

              Center(
                child:
                    _StatusChip(
                  active:
                      lookingForRoomie,
                  label:
                      lookingForRoomie
                          ? 'Buscando Roomie'
                          : 'No busca Roomie',
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              _DocumentationCard(
                loaded:
                    documentationLoaded,
                onTap:
                    _openDocumentation,
              ),

              const SizedBox(
                height: 16,
              ),

              if (!profileCompleted)
                Container(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      const Text(
                    'Tu perfil todavía no está completo.',
                    textAlign:
                        TextAlign.center,
                  ),
                ),

              const SizedBox(
                height: 24,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      _editProfile,
                  icon:
                      const Icon(
                    Icons.edit_outlined,
                  ),
                  label:
                      const Text(
                    'Editar perfil Roomie',
                  ),
                ),
              ),

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
                  height: 8,
                ),

                Text(
                  bio,
                  style:
                      AppTextStyles
                          .bodyMedium,
                ),

                const SizedBox(
                  height: 24,
                ),
              ],

              const _SectionTitle(
                title:
                    'Qué estoy buscando',
              ),

              const SizedBox(
                height: 12,
              ),

              _InfoRow(
                icon:
                    Icons
                        .payments_outlined,
                label:
                    'Presupuesto',
                value:
                    _formatBudget(),
              ),

              if (preferredZone !=
                      null &&
                  preferredZone
                      .isNotEmpty)
                _InfoRow(
                  icon:
                      Icons
                          .location_on_outlined,
                  label:
                      'Zona preferida',
                  value:
                      preferredZone,
                ),

              const SizedBox(
                height: 24,
              ),

              const _SectionTitle(
                title:
                    'Convivencia',
              ),

              const SizedBox(
                height: 12,
              ),

              _InfoRow(
                icon:
                    Icons
                        .smoking_rooms_outlined,
                label:
                    'Fuma',
                value:
                    smoker == null
                        ? 'Sin definir'
                        : smoker
                            ? 'Sí'
                            : 'No',
              ),

              _InfoRow(
                icon:
                    Icons
                        .pets_outlined,
                label:
                    'Tiene mascotas',
                value:
                    hasPets == null
                        ? 'Sin definir'
                        : hasPets
                            ? 'Sí'
                            : 'No',
              ),

              _InfoRow(
                icon:
                    Icons
                        .favorite_outline,
                label:
                    'Acepta mascotas',
                value:
                    acceptsPets
                        ? 'Sí'
                        : 'No',
              ),

              if (cleanlinessLevel !=
                  null)
                _InfoRow(
                  icon:
                      Icons
                          .cleaning_services_outlined,
                  label:
                      'Nivel de orden',
                  value:
                      '$cleanlinessLevel / 5',
                ),

              if (socialLevel !=
                  null)
                _InfoRow(
                  icon:
                      Icons
                          .groups_outlined,
                  label:
                      'Sociabilidad',
                  value:
                      '$socialLevel / 5',
                ),

              if (workSchedule !=
                      null &&
                  workSchedule
                      .isNotEmpty)
                _InfoRow(
                  icon:
                      Icons
                          .schedule_outlined,
                  label:
                      'Horario / rutina',
                  value:
                      workSchedule,
                ),

              if (lifestyle !=
                      null &&
                  lifestyle
                      .isNotEmpty)
                _InfoRow(
                  icon:
                      Icons
                          .self_improvement_outlined,
                  label:
                      'Estilo de vida',
                  value:
                      lifestyle,
                ),

              const SizedBox(
                height: 32,
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _logout,
                  icon:
                      const Icon(
                    Icons.logout,
                  ),
                  label:
                      const Text(
                    'Cerrar sesión',
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentationCard
    extends StatelessWidget {
  final bool loaded;
  final VoidCallback onTap;

  const _DocumentationCard({
    required this.loaded,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
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
        child: Container(
          padding:
              const EdgeInsets.all(
            16,
          ),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            border:
                Border.all(
              color:
                  loaded
                      ? AppColors.success
                      : AppColors.surface,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  color:
                      loaded
                          ? AppColors.surface
                          : AppColors.background,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child:
                    Icon(
                  loaded
                      ? Icons
                          .check_circle_outline
                      : Icons
                          .badge_outlined,
                  color:
                      loaded
                          ? AppColors.success
                          : AppColors.primary,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      loaded
                          ? 'Documentación cargada'
                          : 'Documentación pendiente',
                      style:
                          const TextStyle(
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      loaded
                          ? 'Tu documentación ya está cargada.'
                          : 'Cargala para poder conectar con otros Roomies.',
                      style:
                          AppTextStyles
                              .bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Icon(
                Icons.chevron_right,
                color:
                    loaded
                        ? AppColors.success
                        : AppColors.primary,
              ),
            ],
          ),
        ),
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

class _InfoRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color:
                AppColors.primary,
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
                  label,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    color:
                        AppColors
                            .textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  value,
                  style:
                      AppTextStyles
                          .bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip
    extends StatelessWidget {
  final bool active;
  final String label;

  const _StatusChip({
    required this.active,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            active
                ? AppColors.surface
                : AppColors.background,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
        border:
            Border.all(
          color:
              active
                  ? AppColors.primary
                  : AppColors.neutral,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            active
                ? Icons.check_circle
                : Icons
                    .pause_circle_outline,
            size:
                17,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            label,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}