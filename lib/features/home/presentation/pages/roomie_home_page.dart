import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';

class RoomieHomePage extends StatefulWidget {
  final Set<String> favoritePropertyIds;
  final Future<void> Function(String propertyId) onToggleFavorite;

  const RoomieHomePage({
    super.key,
    required this.favoritePropertyIds,
    required this.onToggleFavorite,
  });

  @override
  State<RoomieHomePage> createState() => _RoomieHomePageState();
}

class _RoomieHomePageState extends State<RoomieHomePage> {
  String? userName;

  bool isLoadingName = true;
  bool isLoadingProperties = true;

  List<Map<String, dynamic>> properties = [];

  @override
  void initState() {
    super.initState();

    _loadUserName();
    _loadProperties();
  }

  Future<void> _loadUserName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        userName = profile['full_name'] as String?;
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
      final data = await Supabase.instance.client
          .from('properties')
          .select('''
            *,
            property_images (
              image_url,
              position
            )
          ''')
          .eq('status', 'published')
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;

      setState(() {
        properties = List<Map<String, dynamic>>.from(data);
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
          content: Text('No se pudieron cargar las propiedades: $error'),
          backgroundColor: AppColors.error,
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

  @override
  Widget build(BuildContext context) {
    final firstName = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim().split(' ').first
        : 'Roomie';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadUserName(), _loadProperties()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoadingName ? 'Hola 👋' : 'Hola, $firstName 👋',
                  style: AppTextStyles.titleLarge,
                ),

                const SizedBox(height: 8),

                const Text(
                  '¿Qué estás buscando hoy?',
                  style: AppTextStyles.bodyLarge,
                ),

                const SizedBox(height: 24),

                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar alquileres, zonas...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.tune),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Propiedades recomendadas',
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver todas'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (isLoadingProperties)
                  const SizedBox(
                    height: 315,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (properties.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.home_work_outlined,
                          size: 48,
                          color: AppColors.secondary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Todavía no hay propiedades publicadas.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyLarge,
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 315,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: properties.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        final property = properties[index];

                        final propertyId = property['id'].toString();

                        return _PropertyCard(
                          property: property,
                          isFavorite: widget.favoritePropertyIds.contains(
                            propertyId,
                          ),
                          onFavoritePressed: () {
                            widget.onToggleFavorite(propertyId);
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PropertyDetailScreen(
                                  property: property,
                                  isFavorite: widget.favoritePropertyIds
                                      .contains(propertyId),
                                  onToggleFavorite: widget.onToggleFavorite,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 32),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Roomies sugeridos',
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    const SizedBox(width: 8),

                    TextButton(
                      onPressed: () {},
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                const _RoomieCard(
                  name: 'Agustín',
                  age: 24,
                  description: 'Busca compartir apartamento en Montevideo.',
                ),

                const SizedBox(height: 12),

                const _RoomieCard(
                  name: 'Lucía',
                  age: 26,
                  description: 'Busca roomie para Cordón o Parque Rodó.',
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;

  const _PropertyCard({
    required this.property,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoritePressed,
  });

  String? _getMainImageUrl() {
    final rawImages = property['property_images'];

    if (rawImages == null || rawImages is! List || rawImages.isEmpty) {
      return null;
    }

    final images = List<Map<String, dynamic>>.from(rawImages);

    images.sort((a, b) {
      final aPosition = a['position'] as int? ?? 0;

      final bPosition = b['position'] as int? ?? 0;

      return aPosition.compareTo(bPosition);
    });

    final url = images.first['image_url'];

    if (url == null || url.toString().trim().isEmpty) {
      return null;
    }

    return url.toString();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getMainImageUrl();

    final neighborhood = property['neighborhood'];
    final city = property['city'];

    String location = '';

    if (neighborhood != null && neighborhood.toString().trim().isNotEmpty) {
      location = neighborhood.toString();
    }

    if (city != null && city.toString().trim().isNotEmpty) {
      if (location.isNotEmpty) {
        location += ', ';
      }

      location += city.toString();
    }

    final currency = property['currency'] ?? 'UYU';

    final price = property['price'] ?? 0;

    return GestureDetector(
  onTap: onTap,
  child: Container(
    width: 280,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(
                            Icons.apartment_rounded,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 52,
                                color: AppColors.secondary,
                              ),
                            ),
                          );
                        },
                      ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: onFavoritePressed,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property['title'] ?? 'Sin título',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodyMedium,
                          ),
                        ),
                      ],
                    ),

                  const Spacer(),

                  Text(
                    '$currency $price / mes',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Icon(
                        Icons.bed_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text('${property['bedrooms'] ?? 0}'),
                      const SizedBox(width: 16),
                      const Icon(
                        Icons.bathtub_outlined,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text('${property['bathrooms'] ?? 0}'),
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

class _RoomieCard extends StatelessWidget {
  final String name;
  final int age;
  final String description;

  const _RoomieCard({
    required this.name,
    required this.age,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.person, color: AppColors.primary),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name, $age',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),

          const Icon(Icons.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }
}
