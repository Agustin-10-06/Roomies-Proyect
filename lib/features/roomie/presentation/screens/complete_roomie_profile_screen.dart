import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CompleteRoomieProfileScreen extends StatefulWidget {
  const CompleteRoomieProfileScreen({super.key});

  @override
  State<CompleteRoomieProfileScreen> createState() =>
      _CompleteRoomieProfileScreenState();
}

class _CompleteRoomieProfileScreenState
    extends State<CompleteRoomieProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _occupationController = TextEditingController();
  final _bioController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();
  final _preferredZoneController = TextEditingController();
  final _lifestyleController = TextEditingController();
  final _workScheduleController = TextEditingController();

  DateTime? birthDate;
  DateTime? moveInDate;

  bool? smoker;
  bool? hasPets;

  bool acceptsPets = true;
  bool lookingForProperty = true;
  bool lookingForRoomie = false;

  double cleanlinessLevel = 3;
  double socialLevel = 3;

  bool isLoading = true;
  bool isSaving = false;

  String? existingPhotoUrl;
  XFile? selectedPhoto;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
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
          .eq('user_id', user.id)
          .maybeSingle();

      if (data != null) {
        _occupationController.text =
            data['occupation']?.toString() ?? '';

        _bioController.text =
            data['bio']?.toString() ?? '';

        _budgetMinController.text =
            data['budget_min']?.toString() ?? '';

        _budgetMaxController.text =
            data['budget_max']?.toString() ?? '';

        _preferredZoneController.text =
            data['preferred_zone']?.toString() ?? '';

        _lifestyleController.text =
            data['lifestyle']?.toString() ?? '';

        _workScheduleController.text =
            data['work_schedule']?.toString() ?? '';

        final birthDateValue =
            data['birth_date']?.toString();

        final moveInDateValue =
            data['move_in_date']?.toString();

        birthDate = birthDateValue != null
            ? DateTime.tryParse(birthDateValue)
            : null;

        moveInDate = moveInDateValue != null
            ? DateTime.tryParse(moveInDateValue)
            : null;

        smoker = data['smoker'] as bool?;
        hasPets = data['has_pets'] as bool?;

        acceptsPets =
            data['accepts_pets'] as bool? ?? true;

        lookingForProperty =
            data['looking_for_property'] as bool? ?? true;

        lookingForRoomie =
            data['looking_for_roomie'] as bool? ?? false;

        cleanlinessLevel =
            (data['cleanliness_level'] as num?)
                    ?.toDouble() ??
                3;

        socialLevel =
            (data['social_level'] as num?)
                    ?.toDouble() ??
                3;

        existingPhotoUrl =
            data['profile_photo_url']?.toString();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el perfil: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (photo == null) return;

    setState(() {
      selectedPhoto = photo;
    });
  }

  Future<String?> _uploadProfilePhoto() async {
    if (selectedPhoto == null) {
      return existingPhotoUrl;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return null;

    final extension =
        selectedPhoto!.path.split('.').last.toLowerCase();

    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}.$extension';

    final storagePath =
        '${user.id}/$fileName';

    await supabase.storage
        .from('roomie-profile-photos')
        .upload(
          storagePath,
          File(selectedPhoto!.path),
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    return supabase.storage
        .from('roomie-profile-photos')
        .getPublicUrl(storagePath);
  }

  Future<void> _selectBirthDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: birthDate ??
          DateTime(
            now.year - 25,
            now.month,
            now.day,
          ),
      firstDate: DateTime(1940),
      lastDate: DateTime(
        now.year - 18,
        now.month,
        now.day,
      ),
    );

    if (selected == null) return;

    setState(() {
      birthDate = selected;
    });
  }

  Future<void> _selectMoveInDate() async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: moveInDate ?? now,
      firstDate: now,
      lastDate: DateTime(
        now.year + 3,
      ),
    );

    if (selected == null) return;

    setState(() {
      moveInDate = selected;
    });
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Seleccionar fecha';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (birthDate == null) {
      _showError(
        'Seleccioná tu fecha de nacimiento.',
      );
      return;
    }

    if (smoker == null) {
      _showError(
        'Indicá si fumás.',
      );
      return;
    }

    if (hasPets == null) {
      _showError(
        'Indicá si tenés mascotas.',
      );
      return;
    }

    final budgetMin = double.tryParse(
      _budgetMinController.text
          .trim()
          .replaceAll(',', '.'),
    );

    final budgetMax = double.tryParse(
      _budgetMaxController.text
          .trim()
          .replaceAll(',', '.'),
    );

    if (budgetMin == null ||
        budgetMax == null) {
      _showError(
        'Ingresá un presupuesto válido.',
      );
      return;
    }

    if (budgetMin > budgetMax) {
      _showError(
        'El presupuesto mínimo no puede ser mayor al máximo.',
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      final photoUrl =
          await _uploadProfilePhoto();

      final profileCompleted =
          photoUrl != null &&
          _occupationController.text
              .trim()
              .isNotEmpty &&
          _bioController.text
              .trim()
              .isNotEmpty &&
          _preferredZoneController.text
              .trim()
              .isNotEmpty;

      await supabase
          .from('roomie_profiles')
          .update({
            'birth_date':
                birthDate!.toIso8601String().split('T').first,
            'occupation':
                _occupationController.text.trim(),
            'bio':
                _bioController.text.trim(),
            'budget_min':
                budgetMin,
            'budget_max':
                budgetMax,
            'preferred_zone':
                _preferredZoneController.text.trim(),
            'looking_for_property':
                lookingForProperty,
            'looking_for_roomie':
                lookingForRoomie,
            'smoker':
                smoker,
            'has_pets':
                hasPets,
            'lifestyle':
                _lifestyleController.text.trim(),
            'move_in_date':
                moveInDate
                    ?.toIso8601String()
                    .split('T')
                    .first,
            'accepts_pets':
                acceptsPets,
            'cleanliness_level':
                cleanlinessLevel.round(),
            'social_level':
                socialLevel.round(),
            'work_schedule':
                _workScheduleController.text.trim(),
            'profile_photo_url':
                photoUrl,
            'profile_completed':
                profileCompleted,
          })
          .eq(
            'user_id',
            user.id,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Perfil actualizado correctamente.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      _showError(
        error.message,
      );
    } catch (error) {
      if (!mounted) return;

      _showError(
        'No se pudo guardar el perfil: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _occupationController.dispose();
    _bioController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    _preferredZoneController.dispose();
    _lifestyleController.dispose();
    _workScheduleController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi perfil Roomie',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildPhotoSection(),

              const SizedBox(height: 28),

              Text(
                'Sobre vos',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller:
                    _occupationController,
                decoration:
                    const InputDecoration(
                  labelText: 'Ocupación',
                  hintText:
                      'Ej. Estudiante, diseñador, contador...',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Ingresá tu ocupación.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Fecha de nacimiento',
                ),
                subtitle: Text(
                  _formatDate(
                    birthDate,
                  ),
                ),
                trailing:
                    const Icon(
                  Icons.calendar_month_outlined,
                ),
                onTap:
                    _selectBirthDate,
              ),

              const SizedBox(height: 8),

              TextFormField(
                controller:
                    _bioController,
                minLines: 4,
                maxLines: 7,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Contanos sobre vos',
                  hintText:
                      'Qué hacés, cómo sos, qué buscás en una convivencia...',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Escribí una breve descripción.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              Text(
                'Qué estás buscando',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child:
                        TextFormField(
                      controller:
                          _budgetMinController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Presupuesto mín.',
                        prefixText:
                            '\$ ',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Ingresá un monto.';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                        TextFormField(
                      controller:
                          _budgetMaxController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Presupuesto máx.',
                        prefixText:
                            '\$ ',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Ingresá un monto.';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller:
                    _preferredZoneController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Zona preferida',
                  hintText:
                      'Ej. Pocitos, Cordón, Centro...',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Ingresá una zona.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              ListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Fecha estimada de mudanza',
                ),
                subtitle: Text(
                  _formatDate(
                    moveInDate,
                  ),
                ),
                trailing:
                    const Icon(
                  Icons.event_outlined,
                ),
                onTap:
                    _selectMoveInDate,
              ),

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Estoy buscando propiedad',
                ),
                value:
                    lookingForProperty,
                onChanged: (value) {
                  setState(() {
                    lookingForProperty =
                        value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Estoy buscando Roomie',
                ),
                subtitle:
                    const Text(
                  'Tu perfil podrá aparecer en la sección de Roomies.',
                ),
                value:
                    lookingForRoomie,
                onChanged: (value) {
                  setState(() {
                    lookingForRoomie =
                        value;
                  });
                },
              ),

              const SizedBox(height: 28),

              Text(
                'Convivencia',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 10),

              _buildBooleanChoice(
                title: '¿Fumás?',
                value: smoker,
                onChanged: (value) {
                  setState(() {
                    smoker = value;
                  });
                },
              ),

              const SizedBox(height: 8),

              _buildBooleanChoice(
                title:
                    '¿Tenés mascotas?',
                value: hasPets,
                onChanged: (value) {
                  setState(() {
                    hasPets = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding:
                    EdgeInsets.zero,
                title: const Text(
                  'Acepto convivir con mascotas',
                ),
                value:
                    acceptsPets,
                onChanged: (value) {
                  setState(() {
                    acceptsPets =
                        value;
                  });
                },
              ),

              const SizedBox(height: 16),

              Text(
                'Nivel de orden',
                style:
                    AppTextStyles.bodyMedium,
              ),

              Slider(
                value:
                    cleanlinessLevel,
                min: 1,
                max: 5,
                divisions: 4,
                label:
                    cleanlinessLevel
                        .round()
                        .toString(),
                onChanged: (value) {
                  setState(() {
                    cleanlinessLevel =
                        value;
                  });
                },
              ),

              Text(
                '1 = relajado · 5 = muy ordenado',
                style:
                    AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 20),

              Text(
                'Nivel de sociabilidad',
                style:
                    AppTextStyles.bodyMedium,
              ),

              Slider(
                value:
                    socialLevel,
                min: 1,
                max: 5,
                divisions: 4,
                label:
                    socialLevel
                        .round()
                        .toString(),
                onChanged: (value) {
                  setState(() {
                    socialLevel =
                        value;
                  });
                },
              ),

              Text(
                '1 = muy tranquilo · 5 = muy sociable',
                style:
                    AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller:
                    _workScheduleController,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Horario / rutina',
                  hintText:
                      'Ej. Trabajo de 9 a 18, estudio de noche...',
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller:
                    _lifestyleController,
                minLines: 3,
                maxLines: 5,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Estilo de vida',
                  hintText:
                      'Ej. tranquilo, deportista, estudio mucho, salgo los fines de semana...',
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 52,
                child:
                    FilledButton(
                  onPressed:
                      isSaving
                          ? null
                          : _saveProfile,
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color:
                                AppColors.white,
                          ),
                        )
                      : const Text(
                          'Guardar perfil',
                        ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    ImageProvider? imageProvider;

    if (selectedPhoto != null) {
      imageProvider = FileImage(
        File(selectedPhoto!.path),
      );
    } else if (existingPhotoUrl != null &&
        existingPhotoUrl!.isNotEmpty) {
      imageProvider =
          NetworkImage(existingPhotoUrl!);
    }

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 58,
            backgroundColor:
                AppColors.surface,
            backgroundImage:
                imageProvider,
            child: imageProvider == null
                ? const Icon(
                    Icons.person,
                    size: 58,
                    color:
                        AppColors.secondary,
                  )
                : null,
          ),

          const SizedBox(height: 12),

          TextButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(
              Icons.photo_camera_outlined,
            ),
            label: Text(
              imageProvider == null
                  ? 'Agregar foto'
                  : 'Cambiar foto',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooleanChoice({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              AppTextStyles.bodyMedium,
        ),

        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label:
                    const Text('Sí'),
                selected:
                    value == true,
                onSelected: (_) {
                  onChanged(true);
                },
              ),
            ),

            const SizedBox(
              width: 10,
            ),

            Expanded(
              child: ChoiceChip(
                label:
                    const Text('No'),
                selected:
                    value == false,
                onSelected: (_) {
                  onChanged(false);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}