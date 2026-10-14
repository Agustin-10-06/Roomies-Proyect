import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CreatePropertyScreen extends StatefulWidget {
  const CreatePropertyScreen({super.key});

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

  String propertyType = 'apartment';
  String rentalType = 'complete_property';
  String currency = 'UYU';

  int bedrooms = 1;
  int bathrooms = 1;

  bool furnished = false;
  bool petsAllowed = false;
  bool isLoading = false;

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

  Future<void> _createProperty() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay sesión activa.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await Supabase.instance.client.from('properties').insert({
        'owner_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'property_type': propertyType,
        'rental_type': rentalType,
        'price': double.parse(_priceController.text.replaceAll(',', '.')),
        'currency': currency,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'city': _cityController.text.trim(),
        'neighborhood': _neighborhoodController.text.trim().isEmpty
            ? null
            : _neighborhoodController.text.trim(),
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'furnished': furnished,
        'pets_allowed': petsAllowed,
        'status': 'published',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Propiedad publicada correctamente.'),
        ),
      );

      Navigator.pop(context, true);
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
          content: Text('Ocurrió un error: $error'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicar propiedad'),
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
                  hintText: 'Ej: Apartamento luminoso en Pocitos',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
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
                  hintText: 'Contá los detalles principales...',
                ),
              ),

              const SizedBox(height: 20),

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
                  if (value != null) {
                    setState(() {
                      propertyType = value;
                    });
                  }
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
                    child: Text('Propiedad completa'),
                  ),
                  DropdownMenuItem(
                    value: 'private_room',
                    child: Text('Habitación privada'),
                  ),
                  DropdownMenuItem(
                    value: 'shared_room',
                    child: Text('Habitación compartida'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      rentalType = value;
                    });
                  }
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Precio mensual',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresá el precio';
                        }

                        final parsed = double.tryParse(
                          value.replaceAll(',', '.'),
                        );

                        if (parsed == null || parsed < 0) {
                          return 'Precio inválido';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: currency,
                      decoration: const InputDecoration(
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
                        if (value != null) {
                          setState(() {
                            currency = value;
                          });
                        }
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
                  if (bedrooms > 0) {
                    setState(() {
                      bedrooms--;
                    });
                  }
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
                  if (bathrooms > 0) {
                    setState(() {
                      bathrooms--;
                    });
                  }
                },
                onPlus: () {
                  setState(() {
                    bathrooms++;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Amoblado'),
                value: furnished,
                onChanged: (value) {
                  setState(() {
                    furnished = value;
                  });
                },
              ),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Acepta mascotas'),
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresá la ciudad';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _neighborhoodController,
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

              FilledButton(
                onPressed: isLoading ? null : _createProperty,
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Text(
                        'Publicar propiedad',
                        style: AppTextStyles.button,
                      ),
              ),
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
          icon: const Icon(Icons.remove_circle_outline),
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
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}