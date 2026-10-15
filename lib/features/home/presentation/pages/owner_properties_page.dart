import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/create_property_screen.dart';

class OwnerPropertiesPage extends StatefulWidget {
  const OwnerPropertiesPage({super.key});

  @override
  State<OwnerPropertiesPage> createState() =>
      _OwnerPropertiesPageState();
}

class _OwnerPropertiesPageState extends State<OwnerPropertiesPage> {
  bool isLoading = true;

  List<Map<String, dynamic>> properties = [];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('properties')
          .select('''
            *,
            property_images (
              image_url,
              position
            )
          ''')
          .eq('owner_id', user.id)
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) return;

      setState(() {
        properties =
            List<Map<String, dynamic>>.from(data);
      });
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
            'Ocurrió un error al cargar las propiedades: $error',
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

  Future<void> _updateStatus(
    String propertyId,
    String newStatus,
  ) async {
    try {
      await Supabase.instance.client
          .from('properties')
          .update({
            'status': newStatus,
          })
          .eq(
            'id',
            propertyId,
          );

      await _loadProperties();

      if (!mounted) return;

      String message;

      switch (newStatus) {
        case 'published':
          message =
              'Propiedad publicada correctamente.';
          break;

        case 'inactive':
          message = 'Propiedad pausada.';
          break;

        case 'rented':
          message =
              'Propiedad marcada como alquilada.';
          break;

        default:
          message = 'Estado actualizado.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
            'No se pudo actualizar la propiedad: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteProperty(
    String propertyId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Eliminar propiedad',
          ),
          content: const Text(
            'Esta acción no se puede deshacer. '
            '¿Querés eliminar esta propiedad?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancelar',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.error,
              ),
              child: const Text(
                'Eliminar',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('properties')
          .delete()
          .eq(
            'id',
            propertyId,
          );

      await _loadProperties();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Propiedad eliminada correctamente.',
          ),
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
            'No se pudo eliminar la propiedad: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _editProperty(
    Map<String, dynamic> property,
  ) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreatePropertyScreen(
          property: property,
        ),
      ),
    );

    if (updated == true) {
      await _loadProperties();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis propiedades',
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });

              _loadProperties();
            },
            icon: const Icon(
              Icons.refresh,
            ),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : properties.isEmpty
                ? RefreshIndicator(
                    onRefresh:
                        _loadProperties,
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      children: const [
                        SizedBox(
                          height: 160,
                        ),
                        Icon(
                          Icons
                              .home_work_outlined,
                          size: 64,
                          color: AppColors
                              .secondary,
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Todavía no publicaste propiedades.',
                          textAlign:
                              TextAlign.center,
                          style: AppTextStyles
                              .bodyLarge,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh:
                        _loadProperties,
                    child:
                        ListView.separated(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      itemCount:
                          properties.length,
                      separatorBuilder:
                          (_, __) {
                        return const SizedBox(
                          height: 16,
                        );
                      },
                      itemBuilder:
                          (context, index) {
                        final property =
                            properties[index];

                        return _OwnerPropertyCard(
                          property:
                              property,
                          onEdit: () {
                            _editProperty(
                              property,
                            );
                          },
                          onStatusChange:
                              (status) {
                            _updateStatus(
                              property['id']
                                  as String,
                              status,
                            );
                          },
                          onDelete: () {
                            _deleteProperty(
                              property['id']
                                  as String,
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _OwnerPropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;

  final VoidCallback onEdit;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onDelete;

  const _OwnerPropertyCard({
    required this.property,
    required this.onEdit,
    required this.onStatusChange,
    required this.onDelete,
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
        List<Map<String, dynamic>>.from(
      rawImages,
    );

    images.sort((a, b) {
      final aPosition =
          a['position'] as int? ?? 0;

      final bPosition =
          b['position'] as int? ?? 0;

      return aPosition.compareTo(
        bPosition,
      );
    });

    final url =
        images.first['image_url'];

    if (url == null ||
        url.toString().trim().isEmpty) {
      return null;
    }

    return url.toString();
  }

  @override
  Widget build(BuildContext context) {
    final price = property['price'];
    final currency =
        property['currency'] ?? 'UYU';
    final status =
        property['status'] ?? 'inactive';

    final neighborhood =
        property['neighborhood'];
    final city = property['city'];

    final imageUrl =
        _getMainImageUrl();

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
        city.toString().trim().isNotEmpty) {
      if (location.isNotEmpty) {
        location += ', ';
      }

      location += city.toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.04,
            ),
            blurRadius: 12,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _PropertyImage(
            imageUrl: imageUrl,
          ),

          Padding(
            padding:
                const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Expanded(
                      child: Text(
                        property['title'] ??
                            'Sin título',
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style: AppTextStyles
                            .titleMedium,
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    _StatusBadge(
                      status: status,
                    ),

                    PopupMenuButton<
                        String>(
                      tooltip: 'Opciones',
                      onSelected:
                          (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                            break;

                          case 'published':
                            onStatusChange(
                              'published',
                            );
                            break;

                          case 'inactive':
                            onStatusChange(
                              'inactive',
                            );
                            break;

                          case 'rented':
                            onStatusChange(
                              'rented',
                            );
                            break;

                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder:
                          (context) {
                        return [
                          const PopupMenuItem<
                              String>(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .edit_outlined,
                                ),
                                SizedBox(
                                  width: 12,
                                ),
                                Text(
                                  'Editar',
                                ),
                              ],
                            ),
                          ),

                          const PopupMenuDivider(),

                          if (status !=
                              'published')
                            const PopupMenuItem<
                                String>(
                              value:
                                  'published',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .visibility_outlined,
                                  ),
                                  SizedBox(
                                    width:
                                        12,
                                  ),
                                  Text(
                                    'Publicar / Reactivar',
                                  ),
                                ],
                              ),
                            ),

                          if (status !=
                              'inactive')
                            const PopupMenuItem<
                                String>(
                              value:
                                  'inactive',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .pause_circle_outline,
                                  ),
                                  SizedBox(
                                    width:
                                        12,
                                  ),
                                  Text(
                                    'Pausar',
                                  ),
                                ],
                              ),
                            ),

                          if (status !=
                              'rented')
                            const PopupMenuItem<
                                String>(
                              value:
                                  'rented',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .key_outlined,
                                  ),
                                  SizedBox(
                                    width:
                                        12,
                                  ),
                                  Text(
                                    'Marcar alquilada',
                                  ),
                                ],
                              ),
                            ),

                          const PopupMenuDivider(),

                          const PopupMenuItem<
                              String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .delete_outline,
                                  color:
                                      AppColors
                                          .error,
                                ),
                                SizedBox(
                                  width: 12,
                                ),
                                Text(
                                  'Eliminar',
                                  style:
                                      TextStyle(
                                    color:
                                        AppColors
                                            .error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                if (location.isNotEmpty)
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .location_on_outlined,
                        size: 18,
                        color: AppColors
                            .textSecondary,
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      Expanded(
                        child: Text(
                          location,
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

                const SizedBox(
                  height: 14,
                ),

                Text(
                  '$currency $price / mes',
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        AppColors.primary,
                  ),
                ),

                const SizedBox(
                  height: 16,
                ),

                Row(
                  children: [
                    const Icon(
                      Icons.bed_outlined,
                      size: 20,
                      color: AppColors
                          .textSecondary,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      '${property['bedrooms'] ?? 0}',
                    ),

                    const SizedBox(
                      width: 20,
                    ),

                    const Icon(
                      Icons
                          .bathtub_outlined,
                      size: 20,
                      color: AppColors
                          .textSecondary,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      '${property['bathrooms'] ?? 0}',
                    ),

                    const SizedBox(
                      width: 20,
                    ),

                    Icon(
                      property['furnished'] ==
                              true
                          ? Icons
                              .chair_outlined
                          : Icons
                              .chair_alt_outlined,
                      size: 20,
                      color: AppColors
                          .textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyImage extends StatelessWidget {
  final String? imageUrl;

  const _PropertyImage({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 190,
      child: imageUrl == null
          ? Container(
              color: AppColors.surface,
              child: const Center(
                child: Icon(
                  Icons
                      .home_work_outlined,
                  size: 54,
                  color:
                      AppColors.secondary,
                ),
              ),
            )
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder:
                  (
                context,
                error,
                stackTrace,
              ) {
                return Container(
                  color:
                      AppColors.surface,
                  child: const Center(
                    child: Icon(
                      Icons
                          .broken_image_outlined,
                      size: 54,
                      color: AppColors
                          .secondary,
                    ),
                  ),
                );
              },
              loadingBuilder:
                  (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress ==
                    null) {
                  return child;
                }

                return Container(
                  color:
                      AppColors.surface,
                  child: const Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                );
              },
            ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;

    switch (status) {
      case 'published':
        label = 'Publicada';
        icon =
            Icons.check_circle_outline;
        break;

      case 'draft':
        label = 'Borrador';
        icon =
            Icons.edit_note_outlined;
        break;

      case 'rented':
        label = 'Alquilada';
        icon = Icons.key_outlined;
        break;

      case 'inactive':
      default:
        label = 'Pausada';
        icon =
            Icons.pause_circle_outline;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.primary,
          ),

          const SizedBox(
            width: 5,
          ),

          Text(
            label,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}