import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';

class FavoritesPage extends StatefulWidget {
  final Set<String> favoritePropertyIds;
  final Future<void> Function(String propertyId) onToggleFavorite;

  const FavoritesPage({
    super.key,
    required this.favoritePropertyIds,
    required this.onToggleFavorite,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool isLoading = true;

  List<Map<String, dynamic>> favoriteProperties = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didUpdateWidget(
    covariant FavoritesPage oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (!_setsEqual(
      oldWidget.favoritePropertyIds,
      widget.favoritePropertyIds,
    )) {
      _loadFavorites();
    }
  }

  bool _setsEqual(
    Set<String> a,
    Set<String> b,
  ) {
    return a.length == b.length && a.containsAll(b);
  }

  Future<void> _loadFavorites() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          favoriteProperties = [];
          isLoading = false;
        });
      }

      return;
    }

    if (widget.favoritePropertyIds.isEmpty) {
      if (mounted) {
        setState(() {
          favoriteProperties = [];
          isLoading = false;
        });
      }

      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data = await supabase
          .from('favorites')
          .select('''
            property_id,
            created_at,
            properties (
              *,
              property_images (
                image_url,
                position
              )
            )
          ''')
          .eq('user_id', user.id)
          .order(
            'created_at',
            ascending: false,
          );

      final loadedProperties = <Map<String, dynamic>>[];

      for (final item in data) {
        final property = item['properties'];

        if (property != null) {
          loadedProperties.add(
            Map<String, dynamic>.from(
              property,
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        favoriteProperties = loadedProperties;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los favoritos: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _removeFavorite(
    String propertyId,
  ) async {
    try {
      await widget.onToggleFavorite(
        propertyId,
      );
    } catch (_) {
      // El padre ya muestra el error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Favoritos',
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : favoriteProperties.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadFavorites,
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 140),
                        Icon(
                          Icons.favorite_border,
                          size: 64,
                          color: AppColors.secondary,
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Todavía no guardaste propiedades.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tocá el corazón de una propiedad para guardarla acá.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFavorites,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      itemCount: favoriteProperties.length,
                      separatorBuilder: (_, __) {
                        return const SizedBox(
                          height: 16,
                        );
                      },
                      itemBuilder: (context, index) {
                        final property =
                            favoriteProperties[index];

                        final propertyId =
                            property['id'].toString();

                        return _FavoritePropertyCard(
                          property: property,
                          onRemoveFavorite: () {
                            _removeFavorite(propertyId);
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PropertyDetailScreen(
                                  property: property,
                                  isFavorite: widget
                                      .favoritePropertyIds
                                      .contains(propertyId),
                                  onToggleFavorite:
                                      widget.onToggleFavorite,
                                ),
                              ),
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

class _FavoritePropertyCard extends StatelessWidget {
  final Map<String, dynamic> property;
  final VoidCallback onRemoveFavorite;
  final VoidCallback onTap;

  const _FavoritePropertyCard({
    required this.property,
    required this.onRemoveFavorite,
    required this.onTap,
  });

  String? _getMainImageUrl() {
    final rawImages = property['property_images'];

    if (rawImages == null ||
        rawImages is! List ||
        rawImages.isEmpty) {
      return null;
    }

    final images =
        List<Map<String, dynamic>>.from(rawImages);

    images.sort((a, b) {
      final aPosition =
          a['position'] as int? ?? 0;

      final bPosition =
          b['position'] as int? ?? 0;

      return aPosition.compareTo(
        bPosition,
      );
    });

    final url = images.first['image_url'];

    if (url == null ||
        url.toString().trim().isEmpty) {
      return null;
    }

    return url.toString();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _getMainImageUrl();

    final neighborhood =
        property['neighborhood'];

    final city =
        property['city'];

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

    final currency =
        property['currency'] ?? 'UYU';

    final price =
        property['price'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius:
              BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
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
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
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
                    decoration:
                        const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed:
                          onRemoveFavorite,
                      icon: const Icon(
                        Icons.favorite,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding:
                  const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    property['title'] ??
                        'Sin título',
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        AppTextStyles.titleMedium,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  if (location.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(
                          width: 4,
                        ),
                        Expanded(
                          child: Text(
                            location,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                AppTextStyles.bodyMedium,
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
                      color: AppColors.primary,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons.bed_outlined,
                        size: 20,
                        color:
                            AppColors.textSecondary,
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
                        Icons.bathtub_outlined,
                        size: 20,
                        color:
                            AppColors.textSecondary,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      Text(
                        '${property['bathrooms'] ?? 0}',
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