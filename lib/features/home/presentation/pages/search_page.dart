import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';

class SearchPage extends StatefulWidget {
  final Set<String> favoritePropertyIds;
  final Future<void> Function(String propertyId) onToggleFavorite;

  const SearchPage({
    super.key,
    required this.favoritePropertyIds,
    required this.onToggleFavorite,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController = TextEditingController();

  bool isLoading = true;

  List<Map<String, dynamic>> allProperties = [];
  List<Map<String, dynamic>> filteredProperties = [];

  @override
  void initState() {
    super.initState();

    _loadProperties();

    _searchController.addListener(_filterProperties);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProperties);
    _searchController.dispose();

    super.dispose();
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
          .order('created_at', ascending: false);

      if (!mounted) return;

      final loaded = List<Map<String, dynamic>>.from(data);

      setState(() {
        allProperties = loaded;
        filteredProperties = loaded;
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
          isLoading = false;
        });
      }
    }
  }

  void _filterProperties() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      setState(() {
        filteredProperties = allProperties;
      });

      return;
    }

    final results = allProperties.where((property) {
      final title = (property['title'] ?? '').toString().toLowerCase();

      final city = (property['city'] ?? '').toString().toLowerCase();

      final neighborhood = (property['neighborhood'] ?? '')
          .toString()
          .toLowerCase();

      final description = (property['description'] ?? '')
          .toString()
          .toLowerCase();

      return title.contains(query) ||
          city.contains(query) ||
          neighborhood.contains(query) ||
          description.contains(query);
    }).toList();

    setState(() {
      filteredProperties = results;
    });
  }

  Future<void> _refresh() async {
    await _loadProperties();

    _filterProperties();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar propiedades')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Encontrá tu próximo hogar',
                style: AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 8),

              const Text(
                'Buscá por barrio, ciudad, título o descripción.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Barrio, ciudad o zona',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),

              const SizedBox(height: 24),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredProperties.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 58,
                        color: AppColors.secondary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No encontramos propiedades.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleMedium,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Probá buscando otra ciudad, barrio o palabra.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${filteredProperties.length} '
                  '${filteredProperties.length == 1 ? 'propiedad encontrada' : 'propiedades encontradas'}',
                  style: AppTextStyles.bodyMedium,
                ),

                const SizedBox(height: 16),

                ...filteredProperties.map((property) {
                  final propertyId = property['id'].toString();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SearchPropertyCard(
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
                              isFavorite: widget.favoritePropertyIds.contains(
                                propertyId,
                              ),
                              onToggleFavorite: widget.onToggleFavorite,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }),

                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoritePressed;

  const _SearchPropertyCard({
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
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                width: double.infinity,
                height: 190,
                child: imageUrl == null
                    ? Container(
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(
                            Icons.home_work_outlined,
                            size: 56,
                            color: AppColors.secondary,
                          ),
                        ),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }

                          return Container(
                            color: AppColors.surface,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
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

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title'] ?? 'Sin título',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium,
                ),

                const SizedBox(height: 10),

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

                const SizedBox(height: 14),

                Text(
                  '$currency $price / mes',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    const Icon(
                      Icons.bed_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text('${property['bedrooms'] ?? 0}'),

                    const SizedBox(width: 20),

                    const Icon(
                      Icons.bathtub_outlined,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text('${property['bathrooms'] ?? 0}'),

                    const SizedBox(width: 20),

                    if (property['furnished'] == true)
                      const Icon(
                        Icons.chair_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
