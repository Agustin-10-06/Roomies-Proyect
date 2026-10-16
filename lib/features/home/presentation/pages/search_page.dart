import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/property_detail_screen.dart';

class SearchPage extends StatefulWidget {
  final Set<String> favoritePropertyIds;

  final Future<void> Function(
    String propertyId,
  ) onToggleFavorite;

  final String initialQuery;

  const SearchPage({
    super.key,
    required this.favoritePropertyIds,
    required this.onToggleFavorite,
    this.initialQuery = '',
  });

  @override
  State<SearchPage> createState() =>
      _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _searchController =
      TextEditingController();

  bool isLoading = true;

  List<Map<String, dynamic>>
      allProperties = [];

  List<Map<String, dynamic>>
      filteredProperties = [];

  String selectedType = 'all';

  double? maxPrice;
  int? minBedrooms;

  final List<Map<String, String>>
      propertyTypes = [
    {
      'value': 'all',
      'label': 'Todos',
    },
    {
      'value': 'apartment',
      'label': 'Apartamento',
    },
    {
      'value': 'house',
      'label': 'Casa',
    },
    {
      'value': 'room',
      'label': 'Habitación',
    },
    {
      'value': 'studio',
      'label': 'Monoambiente',
    },
    {
      'value': 'penthouse',
      'label': 'Penthouse',
    },
  ];

  @override
  void initState() {
    super.initState();

    _searchController.text =
        widget.initialQuery;

    _searchController.addListener(
      _filterProperties,
    );

    _loadProperties();
  }

  @override
  void dispose() {
    _searchController.removeListener(
      _filterProperties,
    );

    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadProperties() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data =
          await Supabase.instance.client
              .from('properties')
              .select(
                '''
                *,
                property_images (
                  image_url,
                  position
                )
                ''',
              )
              .eq(
                'status',
                'published',
              )
              .order(
                'created_at',
                ascending: false,
              );

      if (!mounted) return;

      setState(() {
        allProperties =
            List<Map<String, dynamic>>
                .from(data);

        isLoading = false;
      });

      _filterProperties();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            error.message,
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los alquileres: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  void _filterProperties() {
    final query = _normalize(
      _searchController.text.trim(),
    );

    final results =
        allProperties.where(
      (property) {
        final title = _normalize(
          property['title']
                  ?.toString() ??
              '',
        );

        final city = _normalize(
          property['city']
                  ?.toString() ??
              '',
        );

        final neighborhood =
            _normalize(
          property['neighborhood']
                  ?.toString() ??
              '',
        );

        final description =
            _normalize(
          property['description']
                  ?.toString() ??
              '',
        );

        final rawPropertyType =
            property['property_type']
                    ?.toString() ??
                '';

        final propertyType =
            _normalize(
          rawPropertyType,
        );

        final propertyTypeLabel =
            _normalize(
          _propertyTypeLabel(
            rawPropertyType,
          ),
        );

        final matchesSearch =
            query.isEmpty ||
                title.contains(query) ||
                city.contains(query) ||
                neighborhood
                    .contains(query) ||
                description
                    .contains(query) ||
                propertyType
                    .contains(query) ||
                propertyTypeLabel
                    .contains(query);

        final matchesType =
            _matchesPropertyType(
          property,
        );

        final matchesPrice =
            _matchesPrice(
          property,
        );

        final matchesBedrooms =
            _matchesBedrooms(
          property,
        );

        return matchesSearch &&
            matchesType &&
            matchesPrice &&
            matchesBedrooms;
      },
    ).toList();

    if (!mounted) return;

    setState(() {
      filteredProperties = results;
    });
  }

  bool _matchesPropertyType(
    Map<String, dynamic> property,
  ) {
    if (selectedType == 'all') {
      return true;
    }

    final propertyType =
        property['property_type']
            ?.toString()
            .trim()
            .toLowerCase();

    return propertyType ==
        selectedType;
  }

  bool _matchesPrice(
    Map<String, dynamic> property,
  ) {
    if (maxPrice == null) {
      return true;
    }

    final rawPrice =
        property['price'];

    if (rawPrice == null) {
      return false;
    }

    final price =
        double.tryParse(
      rawPrice.toString(),
    );

    if (price == null) {
      return false;
    }

    return price <=
        maxPrice!;
  }

  bool _matchesBedrooms(
    Map<String, dynamic> property,
  ) {
    if (minBedrooms == null) {
      return true;
    }

    final rawBedrooms =
        property['bedrooms'];

    if (rawBedrooms == null) {
      return false;
    }

    final bedrooms =
        int.tryParse(
      rawBedrooms.toString(),
    );

    if (bedrooms == null) {
      return false;
    }

    return bedrooms >=
        minBedrooms!;
  }

  String _normalize(
    String value,
  ) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  String _propertyTypeLabel(
    dynamic value,
  ) {
    switch (value?.toString()) {
      case 'apartment':
        return 'Apartamento';

      case 'house':
        return 'Casa';

      case 'room':
        return 'Habitación';

      case 'studio':
        return 'Monoambiente';

      case 'penthouse':
        return 'Penthouse';

      default:
        return '';
    }
  }

  String _selectedTypeLabel() {
    final item =
        propertyTypes.firstWhere(
      (item) =>
          item['value'] ==
          selectedType,
      orElse: () => {
        'label': 'Todos',
      },
    );

    return item['label'] ??
        'Todos';
  }

  Future<void> _refresh() async {
    await _loadProperties();
  }

  Future<void> _openFilters() async {
    double? tempMaxPrice =
        maxPrice;

    int? tempMinBedrooms =
        minBedrooms;

    final priceController =
        TextEditingController(
      text: maxPrice == null
          ? ''
          : maxPrice!
              .toStringAsFixed(
                0,
              ),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (
        bottomSheetContext,
      ) {
        return StatefulBuilder(
          builder: (
            context,
            setModalState,
          ) {
            return Padding(
              padding:
                  EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 +
                    MediaQuery.of(
                      context,
                    )
                        .viewInsets
                        .bottom,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filtros',
                          style:
                              AppTextStyles
                                  .titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                        icon:
                            const Icon(
                          Icons.close,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  Text(
                    'Precio máximo',
                    style:
                        AppTextStyles
                            .titleMedium,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  TextField(
                    controller:
                        priceController,
                    keyboardType:
                        const TextInputType
                            .numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(
                      hintText:
                          'Ej: 30000',
                      prefixText:
                          '\$ ',
                    ),
                    onChanged:
                        (value) {
                      tempMaxPrice =
                          double
                              .tryParse(
                        value
                            .replaceAll(
                          ',',
                          '.',
                        ),
                      );
                    },
                  ),

                  const SizedBox(
                    height: 24,
                  ),

                  Text(
                    'Dormitorios mínimos',
                    style:
                        AppTextStyles
                            .titleMedium,
                  ),

                  const SizedBox(
                    height: 10,
                  ),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label:
                            const Text(
                          'Cualquiera',
                        ),
                        selected:
                            tempMinBedrooms ==
                                null,
                        onSelected:
                            (_) {
                          setModalState(
                            () {
                              tempMinBedrooms =
                                  null;
                            },
                          );
                        },
                      ),
                      for (final value
                          in [
                        1,
                        2,
                        3,
                        4,
                      ])
                        ChoiceChip(
                          label:
                              Text(
                            '$value+',
                          ),
                          selected:
                              tempMinBedrooms ==
                                  value,
                          onSelected:
                              (_) {
                            setModalState(
                              () {
                                tempMinBedrooms =
                                    value;
                              },
                            );
                          },
                        ),
                    ],
                  ),

                  const SizedBox(
                    height: 28,
                  ),

                  Row(
                    children: [
                      Expanded(
                        child:
                            OutlinedButton(
                          onPressed:
                              () {
                            setModalState(
                              () {
                                tempMaxPrice =
                                    null;

                                tempMinBedrooms =
                                    null;

                                priceController
                                    .clear();
                              },
                            );
                          },
                          child:
                              const Text(
                            'Limpiar',
                          ),
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      Expanded(
                        child:
                            FilledButton(
                          onPressed:
                              () {
                            setState(
                              () {
                                maxPrice =
                                    tempMaxPrice;

                                minBedrooms =
                                    tempMinBedrooms;
                              },
                            );

                            Navigator.pop(
                              context,
                            );

                            _filterProperties();
                          },
                          child:
                              const Text(
                            'Aplicar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    priceController.dispose();
  }

  bool get hasExtraFilters =>
      maxPrice != null ||
      minBedrooms != null;

  void _clearAllFilters() {
    setState(() {
      selectedType = 'all';

      maxPrice = null;

      minBedrooms = null;

      _searchController.clear();
    });

    _filterProperties();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Alquileres',
        ),
      ),
      body: SafeArea(
        child:
            RefreshIndicator(
          onRefresh:
              _refresh,
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(
              20,
            ),
            children: [
              const Text(
                'Encontrá tu próximo hogar',
                style:
                    AppTextStyles
                        .titleLarge,
              ),

              const SizedBox(
                height: 6,
              ),

              const Text(
                'Buscá apartamentos, casas, habitaciones, monoambientes y penthouses.',
                style:
                    AppTextStyles
                        .bodyMedium,
              ),

              const SizedBox(
                height: 20,
              ),

              Row(
                children: [
                  Expanded(
                    child:
                        TextField(
                      controller:
                          _searchController,
                      textInputAction:
                          TextInputAction
                              .search,
                      decoration:
                          InputDecoration(
                        hintText:
                            'Barrio, ciudad o zona',
                        prefixIcon:
                            const Icon(
                          Icons.search,
                        ),
                        suffixIcon:
                            _searchController
                                    .text
                                    .isEmpty
                                ? null
                                : IconButton(
                                    onPressed:
                                        () {
                                      _searchController
                                          .clear();
                                    },
                                    icon:
                                        const Icon(
                                      Icons.close,
                                    ),
                                  ),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Badge(
                    isLabelVisible:
                        hasExtraFilters,
                    child:
                        IconButton
                            .filledTonal(
                      onPressed:
                          _openFilters,
                      icon:
                          const Icon(
                        Icons.tune,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 18,
              ),

              SizedBox(
                height: 42,
                child:
                    ListView.separated(
                  scrollDirection:
                      Axis.horizontal,
                  itemCount:
                      propertyTypes
                          .length,
                  separatorBuilder:
                      (_, __) =>
                          const SizedBox(
                    width: 8,
                  ),
                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final item =
                        propertyTypes[
                            index];

                    final value =
                        item['value']!;

                    final label =
                        item['label']!;

                    return ChoiceChip(
                      label:
                          Text(
                        label,
                      ),
                      selected:
                          selectedType ==
                              value,
                      onSelected:
                          (_) {
                        setState(
                          () {
                            selectedType =
                                value;
                          },
                        );

                        _filterProperties();
                      },
                    );
                  },
                ),
              ),

              if (hasExtraFilters) ...[
                const SizedBox(
                  height: 14,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (maxPrice !=
                        null)
                      InputChip(
                        label:
                            Text(
                          'Hasta \$${maxPrice!.toStringAsFixed(0)}',
                        ),
                        onDeleted:
                            () {
                          setState(
                            () {
                              maxPrice =
                                  null;
                            },
                          );

                          _filterProperties();
                        },
                      ),

                    if (minBedrooms !=
                        null)
                      InputChip(
                        label:
                            Text(
                          '${minBedrooms!}+ dormitorios',
                        ),
                        onDeleted:
                            () {
                          setState(
                            () {
                              minBedrooms =
                                  null;
                            },
                          );

                          _filterProperties();
                        },
                      ),
                  ],
                ),
              ],

              const SizedBox(
                height: 24,
              ),

              if (isLoading)
                const Padding(
                  padding:
                      EdgeInsets.only(
                    top: 80,
                  ),
                  child: Center(
                    child:
                        CircularProgressIndicator(),
                  ),
                )
              else if (filteredProperties
                  .isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 60,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons
                            .home_work_outlined,
                        size: 58,
                        color:
                            AppColors
                                .secondary,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Text(
                        _searchController
                                .text
                                .trim()
                                .isNotEmpty
                            ? 'No encontramos resultados para "${_searchController.text.trim()}".'
                            : selectedType ==
                                    'all'
                                ? 'No encontramos alquileres.'
                                : 'No encontramos ${_selectedTypeLabel().toLowerCase()}.',
                        textAlign:
                            TextAlign.center,
                        style:
                            AppTextStyles
                                .titleMedium,
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      const Text(
                        'Probá otra zona o cambiá los filtros.',
                        textAlign:
                            TextAlign.center,
                        style:
                            AppTextStyles
                                .bodyMedium,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      if (_searchController
                              .text
                              .trim()
                              .isNotEmpty ||
                          selectedType !=
                              'all' ||
                          hasExtraFilters)
                        TextButton(
                          onPressed:
                              _clearAllFilters,
                          child:
                              const Text(
                            'Ver todos los alquileres',
                          ),
                        ),
                    ],
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child:
                          Text(
                        '${filteredProperties.length} '
                        '${filteredProperties.length == 1 ? 'alquiler disponible' : 'alquileres disponibles'}',
                        style:
                            AppTextStyles
                                .bodyMedium,
                      ),
                    ),

                    if (_searchController
                            .text
                            .trim()
                            .isNotEmpty ||
                        selectedType !=
                            'all' ||
                        hasExtraFilters)
                      TextButton(
                        onPressed:
                            _clearAllFilters,
                        child:
                            const Text(
                          'Limpiar',
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                ...filteredProperties.map(
                  (property) {
                    final propertyId =
                        property['id']
                            .toString();

                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 16,
                      ),
                      child:
                          _SearchPropertyCard(
                        property:
                            property,
                        isFavorite: widget
                            .favoritePropertyIds
                            .contains(
                          propertyId,
                        ),
                        propertyTypeLabel:
                            _propertyTypeLabel(
                          property[
                              'property_type'],
                        ),
                        onFavoritePressed:
                            () {
                          widget
                              .onToggleFavorite(
                            propertyId,
                          );
                        },
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PropertyDetailScreen(
                                property:
                                    property,
                                isFavorite: widget
                                    .favoritePropertyIds
                                    .contains(
                                  propertyId,
                                ),
                                onToggleFavorite:
                                    widget
                                        .onToggleFavorite,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchPropertyCard
    extends StatelessWidget {
  final Map<String, dynamic>
      property;

  final bool isFavorite;

  final String
      propertyTypeLabel;

  final VoidCallback onTap;

  final VoidCallback
      onFavoritePressed;

  const _SearchPropertyCard({
    required this.property,
    required this.isFavorite,
    required this.propertyTypeLabel,
    required this.onTap,
    required this.onFavoritePressed,
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
        List<Map<String, dynamic>>
            .from(
      rawImages,
    );

    images.sort(
      (a, b) {
        final aPosition =
            a['position'] as int? ??
                0;

        final bPosition =
            b['position'] as int? ??
                0;

        return aPosition
            .compareTo(
          bPosition,
        );
      },
    );

    final url =
        images.first['image_url'];

    if (url == null ||
        url
            .toString()
            .trim()
            .isEmpty) {
      return null;
    }

    return url.toString();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final imageUrl =
        _getMainImageUrl();

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
          neighborhood
              .toString();
    }

    if (city != null &&
        city
            .toString()
            .trim()
            .isNotEmpty) {
      if (location.isNotEmpty) {
        location += ', ';
      }

      location +=
          city.toString();
    }

    final currency =
        property['currency'] ??
            'UYU';

    final price =
        property['price'] ?? 0;

    final bathrooms =
        property['bathrooms'] ?? 0;

    return Material(
      color:
          AppColors.white,
      borderRadius:
          BorderRadius.circular(
        20,
      ),
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child: Container(
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(
                  alpha: 0.04,
                ),
                blurRadius: 12,
                offset:
                    const Offset(
                  0,
                  4,
                ),
              ),
            ],
          ),
          clipBehavior:
              Clip.antiAlias,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Stack(
                children: [
                  SizedBox(
                    width:
                        double.infinity,
                    height:
                        190,
                    child: imageUrl ==
                            null
                        ? Container(
                            color:
                                AppColors.surface,
                            child:
                                const Center(
                              child:
                                  Icon(
                                Icons
                                    .home_work_outlined,
                                size:
                                    56,
                                color:
                                    AppColors.secondary,
                              ),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit:
                                BoxFit.cover,
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
                                child:
                                    const Center(
                                  child:
                                      CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder:
                                (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                color:
                                    AppColors.surface,
                                child:
                                    const Center(
                                  child:
                                      Icon(
                                    Icons
                                        .broken_image_outlined,
                                    size:
                                        52,
                                    color:
                                        AppColors.secondary,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  if (propertyTypeLabel
                      .isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 12,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              10,
                          vertical:
                              6,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.white,
                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),
                        child:
                            Text(
                          propertyTypeLabel,
                          style:
                              const TextStyle(
                            fontSize:
                                12,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                AppColors.primary,
                          ),
                        ),
                      ),
                    ),

                  Positioned(
                    top: 12,
                    right: 12,
                    child:
                        Container(
                      decoration:
                          const BoxDecoration(
                        color:
                            AppColors.white,
                        shape:
                            BoxShape.circle,
                      ),
                      child:
                          IconButton(
                        onPressed:
                            onFavoritePressed,
                        icon:
                            Icon(
                          isFavorite
                              ? Icons.favorite
                              : Icons
                                  .favorite_border,
                          color:
                              AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding:
                    const EdgeInsets.all(
                  18,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      property[
                              'title'] ??
                          'Sin título',
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          AppTextStyles
                              .titleMedium,
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    if (location
                        .isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            size:
                                18,
                            color:
                                AppColors.textSecondary,
                          ),

                          const SizedBox(
                            width:
                                4,
                          ),

                          Expanded(
                            child:
                                Text(
                              location,
                              maxLines:
                                  1,
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
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.primary,
                      ),
                    ),

                    const SizedBox(
                      height: 14,
                    ),

                    Wrap(
                      spacing:
                          18,
                      runSpacing:
                          10,
                      children: [
                        _PropertyFeature(
                          icon:
                              Icons.bed_outlined,
                          text:
                              '${property['bedrooms'] ?? 0} dorm.',
                        ),

                        _PropertyFeature(
                          icon:
                              Icons.bathtub_outlined,
                          text:
                              '$bathrooms baño${bathrooms == 1 ? '' : 's'}',
                        ),

                        if (property[
                                'furnished'] ==
                            true)
                          const _PropertyFeature(
                            icon:
                                Icons.chair_outlined,
                            text:
                                'Amoblado',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyFeature
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PropertyFeature({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color:
              AppColors.textSecondary,
        ),

        const SizedBox(
          width: 5,
        ),

        Text(
          text,
          style:
              AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}