import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CreatePropertyScreen extends StatefulWidget {
  final Map<String, dynamic>? property;

  const CreatePropertyScreen({
    super.key,
    this.property,
  });

  bool get isEditing => property != null;

  @override
  State<CreatePropertyScreen> createState() =>
      _CreatePropertyScreenState();
}

class _CreatePropertyScreenState extends State<CreatePropertyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  List<XFile> selectedImages = [];

  String propertyType = 'apartment';
  String rentalType = 'complete_property';
  String currency = 'UYU';

  int bedrooms = 1;
  int bathrooms = 1;

  bool furnished = false;
  bool petsAllowed = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    final property = widget.property;

    if (property != null) {
      _titleController.text = property['title'] ?? '';
      _descriptionController.text = property['description'] ?? '';
      _priceController.text = '${property['price'] ?? ''}';
      _cityController.text = property['city'] ?? '';
      _neighborhoodController.text = property['neighborhood'] ?? '';
      _addressController.text = property['address'] ?? '';

      propertyType = property['property_type'] ?? 'apartment';
      rentalType = property['rental_type'] ?? 'complete_property';
      currency = property['currency'] ?? 'UYU';

      bedrooms = property['bedrooms'] ?? 0;
      bathrooms = property['bathrooms'] ?? 0;

      furnished = property['furnished'] ?? false;
      petsAllowed = property['pets_allowed'] ?? false;
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      if (!mounted) return;

      setState(() {
        selectedImages.addAll(images);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron seleccionar las imágenes: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  String _getExtension(String path) {
    final parts = path.split('.');

    if (parts.length < 2) {
      return 'jpg';
    }

    final extension = parts.last.toLowerCase();

    if (extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png' ||
        extension == 'webp') {
      return extension;
    }

    return 'jpg';
  }

  Future<void> _uploadImages({
    required String userId,
    required String propertyId,
  }) async {
    if (selectedImages.isEmpty) return;

    final supabase = Supabase.instance.client;

    for (int index = 0; index < selectedImages.length; index++) {
      final image = selectedImages[index];

      final extension = _getExtension(image.path);

      final timestamp =
          DateTime.now().microsecondsSinceEpoch;

      final fileName =
          '${timestamp}_$index.$extension';

      final storagePath =
          '$userId/$propertyId/$fileName';

      final file = File(image.path);

      await supabase.storage
          .from('property-images')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              upsert: false,
            ),
          );

      final publicUrl = supabase.storage
          .from('property-images')
          .getPublicUrl(storagePath);

      await supabase
          .from('property_images')
          .insert({
            'property_id': propertyId,
            'image_url': publicUrl,
            'position': index,
          });
    }
  }

  Future<void> _saveProperty() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay una sesión activa.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final propertyData = {
        'owner_id': user.id,
        'title': _titleController.text.trim(),
        'description':
            _descriptionController.text.trim(),
        'property_type': propertyType,
        'rental_type': rentalType,
        'price': double.parse(
          _priceController.text.replaceAll(',', '.'),
        ),
        'currency': currency,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'city': _cityController.text.trim(),
        'neighborhood':
            _neighborhoodController.text.trim().isEmpty
                ? null
                : _neighborhoodController.text.trim(),
        'address':
            _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
        'furnished': furnished,
        'pets_allowed': petsAllowed,
      };

      late String propertyId;

      if (widget.isEditing) {
        propertyId =
            widget.property!['id'] as String;

        await supabase
            .from('properties')
            .update(propertyData)
            .eq(
              'id',
              propertyId,
            );
      } else {
        final createdProperty = await supabase
            .from('properties')
            .insert({
              ...propertyData,
              'status': 'published',
            })
            .select('id')
            .single();

        propertyId =
            createdProperty['id'] as String;
      }

      await _uploadImages(
        userId: user.id,
        propertyId: propertyId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Propiedad actualizada correctamente.'
                : 'Propiedad publicada correctamente.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } on StorageException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al subir las imágenes: ${error.message}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message,
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ocurrió un error: $error',
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _neighborhoodController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Editar propiedad'
              : 'Publicar propiedad',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Datos principales',
                style: AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 24),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText:
                      'Ej: Apartamento luminoso en Pocitos',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Ingresá un título';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText:
                      'Contá los detalles principales...',
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: propertyType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de propiedad',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'house',
                    child: Text('Casa'),
                  ),
                  DropdownMenuItem(
                    value: 'apartment',
                    child: Text('Apartamento'),
                  ),
                  DropdownMenuItem(
                    value: 'room',
                    child: Text('Habitación'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    propertyType = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: rentalType,
                decoration: const InputDecoration(
                  labelText: 'Modalidad',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'complete_property',
                    child: Text(
                      'Propiedad completa',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'private_room',
                    child: Text(
                      'Habitación privada',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'shared_room',
                    child: Text(
                      'Habitación compartida',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    rentalType = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Precio',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType:
                          const TextInputType
                              .numberWithOptions(
                        decimal: true,
                      ),
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Precio mensual',
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.trim().isEmpty) {
                          return 'Ingresá el precio';
                        }

                        final parsed =
                            double.tryParse(
                          value.replaceAll(
                            ',',
                            '.',
                          ),
                        );

                        if (parsed == null ||
                            parsed < 0) {
                          return 'Precio inválido';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child:
                        DropdownButtonFormField<
                            String>(
                      initialValue: currency,
                      decoration:
                          const InputDecoration(
                        labelText: 'Moneda',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'UYU',
                          child: Text('UYU'),
                        ),
                        DropdownMenuItem(
                          value: 'USD',
                          child: Text('USD'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;

                        setState(() {
                          currency = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Características',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 12),

              _CounterRow(
                label: 'Dormitorios',
                value: bedrooms,
                onMinus: () {
                  if (bedrooms <= 0) return;

                  setState(() {
                    bedrooms--;
                  });
                },
                onPlus: () {
                  setState(() {
                    bedrooms++;
                  });
                },
              ),

              _CounterRow(
                label: 'Baños',
                value: bathrooms,
                onMinus: () {
                  if (bathrooms <= 0) return;

                  setState(() {
                    bathrooms--;
                  });
                },
                onPlus: () {
                  setState(() {
                    bathrooms++;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Amoblado',
                ),
                value: furnished,
                onChanged: (value) {
                  setState(() {
                    furnished = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Acepta mascotas',
                ),
                value: petsAllowed,
                onChanged: (value) {
                  setState(() {
                    petsAllowed = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              const Text(
                'Ubicación',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Ciudad',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Ingresá la ciudad';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller:
                    _neighborhoodController,
                decoration: const InputDecoration(
                  labelText: 'Barrio',
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Fotos',
                style: AppTextStyles.titleMedium,
              ),

              const SizedBox(height: 8),

              const Text(
                'Agregá fotos claras de la propiedad.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed:
                    isLoading ? null : _pickImages,
                icon: const Icon(
                  Icons
                      .add_photo_alternate_outlined,
                ),
                label: const Text(
                  'Agregar fotos',
                ),
              ),

              if (selectedImages.isNotEmpty) ...[
                const SizedBox(height: 16),

                Text(
                  '${selectedImages.length} foto${selectedImages.length == 1 ? '' : 's'} seleccionada${selectedImages.length == 1 ? '' : 's'}',
                  style: AppTextStyles.bodyMedium,
                ),

                const SizedBox(height: 12),

                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection:
                        Axis.horizontal,
                    itemCount:
                        selectedImages.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(
                      width: 12,
                    ),
                    itemBuilder:
                        (context, index) {
                      final image =
                          selectedImages[index];

                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                            child: Image.file(
                              File(image.path),
                              width: 110,
                              height: 110,
                              fit: BoxFit.cover,
                            ),
                          ),

                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              decoration:
                                  const BoxDecoration(
                                color:
                                    Colors.black54,
                                shape:
                                    BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () {
                                  _removeImage(
                                    index,
                                  );
                                },
                                icon: const Icon(
                                  Icons.close,
                                  color:
                                      Colors.white,
                                  size: 18,
                                ),
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                padding:
                                    EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 32),

              FilledButton(
                onPressed:
                    isLoading ? null : _saveProperty,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              AppColors.white,
                        ),
                      )
                    : Text(
                        widget.isEditing
                            ? 'Guardar cambios'
                            : 'Publicar propiedad',
                        style:
                            AppTextStyles.button,
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

class _CounterRow extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _CounterRow({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge,
          ),
        ),
        IconButton(
          onPressed: onMinus,
          icon: const Icon(
            Icons.remove_circle_outline,
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        IconButton(
          onPressed: onPlus,
          icon: const Icon(
            Icons.add_circle_outline,
          ),
        ),
      ],
    );
  }
}