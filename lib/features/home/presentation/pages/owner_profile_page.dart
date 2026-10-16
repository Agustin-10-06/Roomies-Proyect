import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/screens/welcome_screen.dart';

class OwnerProfilePage extends StatefulWidget {
  const OwnerProfilePage({
    super.key,
  });

  @override
  State<OwnerProfilePage> createState() =>
      _OwnerProfilePageState();
}

class _OwnerProfilePageState extends State<OwnerProfilePage> {
  final ImagePicker _imagePicker = ImagePicker();

  bool isLoading = true;
  bool isUploadingImage = false;

  Map<String, dynamic>? profile;
  Map<String, dynamic>? ownerProfile;

  int publishedPropertiesCount = 0;

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
      if (mounted) {
        setState(() {
          isLoading = true;
        });
      }

      final Map<String, dynamic>? profileData = await supabase
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
          .maybeSingle();

      final Map<String, dynamic>? ownerData = await supabase
          .from('owner_profiles')
          .select(
            '''
            user_id,
            owner_type,
            business_name,
            description,
            contact_phone,
            location,
            website,
            instagram,
            created_at
            ''',
          )
          .eq(
            'user_id',
            user.id,
          )
          .maybeSingle();

      final List<Map<String, dynamic>> propertiesData =
          await supabase
              .from('properties')
              .select('id')
              .eq(
                'owner_id',
                user.id,
              )
              .eq(
                'status',
                'published',
              );

      if (!mounted) return;

      setState(() {
        profile = profileData;
        ownerProfile = ownerData;
        publishedPropertiesCount = propertiesData.length;
        isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
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
            'No se pudo cargar el perfil: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showImageSourcePicker() async {
    if (isUploadingImage) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Elegir imagen',
                  style: AppTextStyles.titleMedium,
                ),

                const SizedBox(height: 18),

                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Elegir de la galería',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      ImageSource.gallery,
                    );
                  },
                ),

                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text(
                    'Sacar una foto',
                  ),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      ImageSource.camera,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickAndUploadImage(source);
  }

  Future<void> _pickAndUploadImage(
    ImageSource source,
  ) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (pickedFile == null) {
      return;
    }

    await _uploadProfileImage(pickedFile);
  }

  Future<void> _uploadProfileImage(
    XFile image,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      isUploadingImage = true;
    });

    try {
      String extension = 'jpg';

      final fileName = image.name;

      if (fileName.contains('.')) {
        final detectedExtension =
            fileName.split('.').last.toLowerCase();

        if (detectedExtension.isNotEmpty) {
          extension = detectedExtension;
        }
      }

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final storagePath =
          '${user.id}/profile_$timestamp.$extension';

      await supabase.storage
          .from('owner-profile-images')
          .upload(
            storagePath,
            File(image.path),
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage
          .from('owner-profile-images')
          .getPublicUrl(storagePath);

      await supabase
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
          })
          .eq(
            'id',
            user.id,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        profile = {
          ...?profile,
          'avatar_url': publicUrl,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isAgency
                ? 'Logo actualizado correctamente.'
                : 'Foto actualizada correctamente.',
          ),
        ),
      );
    } on StorageException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo subir la imagen: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUploadingImage = false;
        });
      }
    }
  }

  bool get _isAgency {
    return ownerProfile?['owner_type']?.toString() == 'agency';
  }

  Future<void> _editProfile() async {
    final fullNameController = TextEditingController(
      text: profile?['full_name']?.toString() ?? '',
    );

    final businessNameController = TextEditingController(
      text: ownerProfile?['business_name']?.toString() ?? '',
    );

    final phoneController = TextEditingController(
      text: ownerProfile?['contact_phone']?.toString() ?? '',
    );

    final locationController = TextEditingController(
      text: ownerProfile?['location']?.toString() ?? '',
    );

    final websiteController = TextEditingController(
      text: ownerProfile?['website']?.toString() ?? '',
    );

    final instagramController = TextEditingController(
      text: ownerProfile?['instagram']?.toString() ?? '',
    );

    final descriptionController = TextEditingController(
      text: ownerProfile?['description']?.toString() ?? '',
    );

    String tempOwnerType =
        ownerProfile?['owner_type']?.toString() ?? 'owner';

    bool modalSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAgency = tempOwnerType == 'agency';

            Future<void> saveProfile() async {
              final supabase = Supabase.instance.client;
              final user = supabase.auth.currentUser;

              if (user == null) {
                return;
              }

              final fullName =
                  fullNameController.text.trim();

              final businessName =
                  businessNameController.text.trim();

              if (fullName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ingresá un nombre.',
                    ),
                  ),
                );

                return;
              }

              if (isAgency && businessName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Ingresá el nombre de la inmobiliaria.',
                    ),
                  ),
                );

                return;
              }

              setModalState(() {
                modalSaving = true;
              });

              try {
                await supabase
                    .from('profiles')
                    .update({
                      'full_name': fullName,
                    })
                    .eq(
                      'id',
                      user.id,
                    );

                await supabase
                    .from('owner_profiles')
                    .upsert(
                  {
                    'user_id': user.id,
                    'owner_type': tempOwnerType,
                    'business_name':
                        isAgency ? businessName : null,
                    'contact_phone':
                        phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                    'location':
                        locationController.text.trim().isEmpty
                            ? null
                            : locationController.text.trim(),
                    'website':
                        isAgency &&
                                websiteController
                                    .text
                                    .trim()
                                    .isNotEmpty
                            ? websiteController.text.trim()
                            : null,
                    'instagram':
                        isAgency &&
                                instagramController
                                    .text
                                    .trim()
                                    .isNotEmpty
                            ? instagramController.text.trim()
                            : null,
                    'description':
                        descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                  },
                  onConflict: 'user_id',
                );

                if (!context.mounted) {
                  return;
                }

                Navigator.pop(
                  context,
                  true,
                );
              } on PostgrestException catch (error) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.message),
                    backgroundColor: AppColors.error,
                  ),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'No se pudo guardar el perfil: $error',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              } finally {
                if (context.mounted) {
                  setModalState(() {
                    modalSaving = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 +
                    MediaQuery.of(context)
                        .viewInsets
                        .bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Editar perfil',
                            style:
                                AppTextStyles.titleLarge,
                          ),
                        ),

                        IconButton(
                          onPressed: modalSaving
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                    false,
                                  );
                                },
                          icon: const Icon(
                            Icons.close,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    DropdownButtonFormField<String>(
                      initialValue: tempOwnerType,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Tipo de perfil',
                        prefixIcon: Icon(
                          Icons.account_circle_outlined,
                        ),
                      ),
                      items:
                          const [
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text(
                            'Propietario',
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'agency',
                          child: Text(
                            'Inmobiliaria',
                          ),
                        ),
                      ],
                      onChanged: modalSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setModalState(() {
                                tempOwnerType = value;
                              });
                            },
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          fullNameController,
                      enabled:
                          !modalSaving,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          InputDecoration(
                        labelText: isAgency
                            ? 'Nombre del responsable'
                            : 'Nombre completo',
                        prefixIcon:
                            const Icon(
                          Icons.person_outline,
                        ),
                      ),
                    ),

                    if (isAgency) ...[
                      const SizedBox(height: 14),

                      TextField(
                        controller:
                            businessNameController,
                        enabled:
                            !modalSaving,
                        textCapitalization:
                            TextCapitalization.words,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Nombre de la inmobiliaria',
                          prefixIcon: Icon(
                            Icons.business_outlined,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          phoneController,
                      enabled:
                          !modalSaving,
                      keyboardType:
                          TextInputType.phone,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Teléfono de contacto',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          locationController,
                      enabled:
                          !modalSaving,
                      textCapitalization:
                          TextCapitalization.words,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Ubicación',
                        hintText:
                            'Ej: Montevideo',
                        prefixIcon: Icon(
                          Icons.location_on_outlined,
                        ),
                      ),
                    ),

                    if (isAgency) ...[
                      const SizedBox(height: 14),

                      TextField(
                        controller:
                            websiteController,
                        enabled:
                            !modalSaving,
                        keyboardType:
                            TextInputType.url,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Sitio web',
                          hintText:
                              'www.inmobiliaria.com',
                          prefixIcon: Icon(
                            Icons.language_outlined,
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextField(
                        controller:
                            instagramController,
                        enabled:
                            !modalSaving,
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Instagram',
                          hintText:
                              '@inmobiliaria',
                          prefixIcon: Icon(
                            Icons.alternate_email,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    TextField(
                      controller:
                          descriptionController,
                      enabled:
                          !modalSaving,
                      maxLines: 4,
                      maxLength: 500,
                      decoration:
                          InputDecoration(
                        labelText: isAgency
                            ? 'Descripción de la inmobiliaria'
                            : 'Sobre vos',
                        alignLabelWithHint: true,
                        prefixIcon:
                            const Padding(
                          padding:
                              EdgeInsets.only(
                            bottom: 70,
                          ),
                          child: Icon(
                            Icons.description_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          FilledButton(
                        onPressed:
                            modalSaving
                                ? null
                                : saveProfile,
                        child: modalSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.white,
                                ),
                              )
                            : const Text(
                                'Guardar cambios',
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved == true) {
      await _loadProfile();
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

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

  String _memberSince() {
    final value =
        ownerProfile?['created_at']?.toString();

    if (value == null ||
        value.isEmpty) {
      return 'Sin definir';
    }

    final date =
        DateTime.tryParse(value);

    if (date == null) {
      return 'Sin definir';
    }

    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return '${months[date.month - 1]} ${date.year}';
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

    final ownerType =
        ownerProfile?['owner_type']
                ?.toString() ??
            'owner';

    final isAgency =
        ownerType == 'agency';

    final fullName =
        profile?['full_name']
                ?.toString() ??
            'Sin nombre';

    final businessName =
        ownerProfile?['business_name']
            ?.toString()
            .trim();

    final displayName =
        isAgency &&
                businessName != null &&
                businessName.isNotEmpty
            ? businessName
            : fullName;

    final avatarUrl =
        profile?['avatar_url']
            ?.toString();

    final description =
        ownerProfile?['description']
            ?.toString()
            .trim();

    final phone =
        ownerProfile?['contact_phone']
            ?.toString()
            .trim();

    final location =
        ownerProfile?['location']
            ?.toString()
            .trim();

    final website =
        ownerProfile?['website']
            ?.toString()
            .trim();

    final instagram =
        ownerProfile?['instagram']
            ?.toString()
            .trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
        ),
        actions: [
          IconButton(
            tooltip:
                'Editar perfil',
            onPressed:
                _editProfile,
            icon:
                const Icon(
              Icons.edit_outlined,
            ),
          ),
        ],
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
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 58,
                      backgroundColor:
                          AppColors.surface,
                      backgroundImage:
                          avatarUrl != null &&
                                  avatarUrl.isNotEmpty
                              ? NetworkImage(
                                  avatarUrl,
                                )
                              : null,
                      child: avatarUrl == null ||
                              avatarUrl.isEmpty
                          ? Icon(
                              isAgency
                                  ? Icons.business_outlined
                                  : Icons.person_outline,
                              size: 58,
                              color:
                                  AppColors.primary,
                            )
                          : null,
                    ),

                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Material(
                        color:
                            AppColors.primary,
                        shape:
                            const CircleBorder(),
                        child: InkWell(
                          customBorder:
                              const CircleBorder(),
                          onTap:
                              isUploadingImage
                                  ? null
                                  : _showImageSourcePicker,
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: isUploadingImage
                                ? const Padding(
                                    padding:
                                        EdgeInsets.all(
                                      10,
                                    ),
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          AppColors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 20,
                                    color:
                                        AppColors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Center(
                child: TextButton.icon(
                  onPressed:
                      isUploadingImage
                          ? null
                          : _showImageSourcePicker,
                  icon: Icon(
                    isAgency
                        ? Icons.image_outlined
                        : Icons.photo_camera_outlined,
                  ),
                  label: Text(
                    isUploadingImage
                        ? 'Subiendo...'
                        : isAgency
                            ? 'Cambiar logo'
                            : 'Cambiar foto',
                  ),
                ),
              ),

              const SizedBox(height: 6),

              Text(
                displayName,
                textAlign:
                    TextAlign.center,
                style:
                    AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 8),

              Center(
                child: _TypeChip(
                  isAgency:
                      isAgency,
                ),
              ),

              if (isAgency) ...[
                const SizedBox(height: 10),

                Text(
                  'Responsable: $fullName',
                  textAlign:
                      TextAlign.center,
                  style:
                      AppTextStyles.bodyMedium,
                ),
              ],

              const SizedBox(height: 26),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon:
                          Icons.home_work_outlined,
                      value:
                          '$publishedPropertiesCount',
                      label:
                          publishedPropertiesCount == 1
                              ? 'Propiedad publicada'
                              : 'Propiedades publicadas',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _StatCard(
                      icon:
                          Icons.calendar_month_outlined,
                      value:
                          _memberSince(),
                      label:
                          'Miembro desde',
                    ),
                  ),
                ],
              ),

              if (description != null &&
                  description.isNotEmpty) ...[
                const SizedBox(height: 28),

                const _SectionTitle(
                  title: 'Acerca de',
                ),

                const SizedBox(height: 10),

                Text(
                  description,
                  style:
                      AppTextStyles.bodyMedium,
                ),
              ],

              const SizedBox(height: 28),

              const _SectionTitle(
                title:
                    'Información de contacto',
              ),

              const SizedBox(height: 12),

              _InfoCard(
                icon:
                    Icons.person_outline,
                title:
                    isAgency
                        ? 'Responsable'
                        : 'Nombre',
                value:
                    fullName,
              ),

              if (phone != null &&
                  phone.isNotEmpty)
                _InfoCard(
                  icon:
                      Icons.phone_outlined,
                  title:
                      'Teléfono',
                  value:
                      phone,
                ),

              if (location != null &&
                  location.isNotEmpty)
                _InfoCard(
                  icon:
                      Icons.location_on_outlined,
                  title:
                      'Ubicación',
                  value:
                      location,
                ),

              if (isAgency &&
                  website != null &&
                  website.isNotEmpty)
                _InfoCard(
                  icon:
                      Icons.language_outlined,
                  title:
                      'Sitio web',
                  value:
                      website,
                ),

              if (isAgency &&
                  instagram != null &&
                  instagram.isNotEmpty)
                _InfoCard(
                  icon:
                      Icons.alternate_email,
                  title:
                      'Instagram',
                  value:
                      instagram,
                ),

              const SizedBox(height: 26),

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
                  label: Text(
                    isAgency
                        ? 'Editar inmobiliaria'
                        : 'Editar perfil',
                  ),
                ),
              ),

              const SizedBox(height: 14),

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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final bool isAgency;

  const _TypeChip({
    required this.isAgency,
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
            AppColors.surface,
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
            isAgency
                ? Icons.business_outlined
                : Icons.home_outlined,
            size: 17,
            color:
                AppColors.primary,
          ),

          const SizedBox(width: 6),

          Text(
            isAgency
                ? 'Inmobiliaria'
                : 'Propietario',
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                AppColors.primary,
          ),

          const SizedBox(height: 8),

          Text(
            value,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            label,
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

class _SectionTitle extends StatelessWidget {
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

class _InfoCard extends StatelessWidget {
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
        border: Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
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

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color:
                        AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    color:
                        AppColors.textPrimary,
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