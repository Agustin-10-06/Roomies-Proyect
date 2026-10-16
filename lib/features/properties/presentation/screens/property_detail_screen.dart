import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Map<String, dynamic> property;
  final bool isFavorite;

  final Future<void> Function(
    String propertyId,
  ) onToggleFavorite;

  const PropertyDetailScreen({
    super.key,
    required this.property,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  State<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
}

class _PropertyDetailScreenState
    extends State<PropertyDetailScreen> {
  late bool isFavorite;

  int currentImageIndex = 0;

  bool isOpeningChat = false;
  bool isLoadingOwner = true;

  Map<String, dynamic>? ownerProfile;

  @override
  void initState() {
    super.initState();

    isFavorite =
        widget.isFavorite;

    _loadOwnerProfile();
  }

  Future<void> _loadOwnerProfile() async {
    final ownerId =
        widget.property['owner_id']
            ?.toString();

    if (ownerId == null ||
        ownerId.isEmpty) {
      if (mounted) {
        setState(() {
          isLoadingOwner = false;
        });
      }

      return;
    }

    try {
      final data =
          await Supabase.instance.client.rpc(
        'get_public_owner_profile',
        params: {
          'profile_id':
              ownerId,
        },
      );

      final rows =
          List<Map<String, dynamic>>
              .from(data);

      if (!mounted) {
        return;
      }

      setState(() {
        ownerProfile =
            rows.isNotEmpty
                ? rows.first
                : null;

        isLoadingOwner = false;
      });
    } catch (error) {
      debugPrint(
        'ERROR PUBLIC OWNER PROFILE: $error',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoadingOwner = false;
      });
    }
  }

  List<String> _getImages() {
    final rawImages =
        widget.property[
            'property_images'];

    if (rawImages == null ||
        rawImages is! List) {
      return [];
    }

    final images =
        List<Map<String, dynamic>>
            .from(
      rawImages,
    );

    images.sort(
      (a, b) {
        final aPosition =
            a['position']
                    as int? ??
                0;

        final bPosition =
            b['position']
                    as int? ??
                0;

        return aPosition
            .compareTo(
          bPosition,
        );
      },
    );

    return images
        .map(
          (image) =>
              image['image_url']
                  ?.toString(),
        )
        .whereType<String>()
        .where(
          (url) =>
              url.isNotEmpty,
        )
        .toList();
  }

  String _getLocation() {
    final neighborhood =
        widget.property[
            'neighborhood'];

    final city =
        widget.property['city'];

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

    return location;
  }

  String _propertyTypeLabel() {
    switch (
        widget.property[
                'property_type']
            ?.toString()) {
      case 'house':
        return 'Casa';

      case 'room':
        return 'Habitación';

      case 'studio':
        return 'Monoambiente';

      case 'penthouse':
        return 'Penthouse';

      case 'apartment':
      default:
        return 'Apartamento';
    }
  }

  String _rentalTypeLabel() {
    switch (
        widget.property[
                'rental_type']
            ?.toString()) {
      case 'private_room':
        return 'Habitación privada';

      case 'shared_room':
        return 'Habitación compartida';

      case 'complete_property':
      default:
        return 'Propiedad completa';
    }
  }

  String _ownerDisplayName() {
    if (ownerProfile == null) {
      return 'Propietario';
    }

    final ownerType =
        ownerProfile!['owner_type']
            ?.toString();

    final businessName =
        ownerProfile![
                'business_name']
            ?.toString()
            .trim();

    final fullName =
        ownerProfile!['full_name']
            ?.toString()
            .trim();

    if (ownerType ==
            'agency' &&
        businessName != null &&
        businessName.isNotEmpty) {
      return businessName;
    }

    if (fullName != null &&
        fullName.isNotEmpty) {
      return fullName;
    }

    return ownerType ==
            'agency'
        ? 'Inmobiliaria'
        : 'Propietario';
  }

  String _ownerTypeLabel() {
    final ownerType =
        ownerProfile?['owner_type']
            ?.toString();

    return ownerType ==
            'agency'
        ? 'Inmobiliaria'
        : 'Propietario';
  }

  String _memberSince() {
    final value =
        ownerProfile?['created_at']
            ?.toString();

    if (value == null ||
        value.isEmpty) {
      return '';
    }

    final date =
        DateTime.tryParse(
      value,
    );

    if (date == null) {
      return '';
    }

    return '${date.year}';
  }

  Future<void> _toggleFavorite() async {
    final propertyId =
        widget.property['id']
            .toString();

    try {
      await widget
          .onToggleFavorite(
        propertyId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isFavorite =
            !isFavorite;
      });
    } catch (_) {
      // El padre maneja el error.
    }
  }

  Future<void> _openChat() async {
    if (isOpeningChat) {
      return;
    }

    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final propertyId =
        widget.property['id']
            .toString();

    final ownerId =
        widget.property['owner_id']
            .toString();

    setState(() {
      isOpeningChat = true;
    });

    try {
      final conversations =
          await supabase
              .from(
                'conversations',
              )
              .select(
                '''
                id,
                property_id,
                roomie_id,
                owner_id
                ''',
              )
              .eq(
                'property_id',
                propertyId,
              )
              .eq(
                'roomie_id',
                user.id,
              )
              .limit(
                1,
              );

      String conversationId;

      if (conversations
          .isNotEmpty) {
        conversationId =
            conversations
                .first['id']
                .toString();
      } else {
        final createdConversation =
            await supabase
                .from(
                  'conversations',
                )
                .insert({
                  'property_id':
                      propertyId,
                  'roomie_id':
                      user.id,
                  'owner_id':
                      ownerId,
                })
                .select(
                  'id',
                )
                .single();

        conversationId =
            createdConversation[
                    'id']
                .toString();
      }

      if (!mounted) {
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(
            conversationId:
                conversationId,
            propertyTitle:
                widget.property[
                            'title']
                        ?.toString() ??
                    'Propiedad',
            ownerId:
                ownerId,
            otherUserName:
                _ownerDisplayName(),
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(
            error.message,
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir el chat: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isOpeningChat = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final images =
        _getImages();

    final location =
        _getLocation();

    final currency =
        widget.property[
                'currency'] ??
            'UYU';

    final price =
        widget.property[
                'price'] ??
            0;

    final description =
        widget.property[
                    'description']
                ?.toString()
                .trim() ??
            '';

    final address =
        widget.property['address']
            ?.toString()
            .trim();

    final ownerAvatar =
        ownerProfile?['avatar_url']
            ?.toString();

    final ownerDescription =
        ownerProfile?['description']
            ?.toString()
            .trim();

    final ownerLocation =
        ownerProfile?['location']
            ?.toString()
            .trim();

    final publishedCount =
        ownerProfile?[
                'published_properties_count'] ??
            0;

    final ownerType =
        ownerProfile?['owner_type']
            ?.toString();

    final isAgency =
        ownerType ==
            'agency';

    return Scaffold(
      body: SafeArea(
        child:
            CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight:
                  300,
              pinned:
                  true,
              leading:
                  Padding(
                padding:
                    const EdgeInsets.all(
                  8,
                ),
                child:
                    CircleAvatar(
                  backgroundColor:
                      AppColors.white,
                  child:
                      IconButton(
                    onPressed:
                        () {
                      Navigator.pop(
                        context,
                      );
                    },
                    icon:
                        const Icon(
                      Icons
                          .arrow_back,
                      color:
                          AppColors.primary,
                    ),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding:
                      const EdgeInsets.all(
                    8,
                  ),
                  child:
                      CircleAvatar(
                    backgroundColor:
                        AppColors.white,
                    child:
                        IconButton(
                      onPressed:
                          _toggleFavorite,
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
              flexibleSpace:
                  FlexibleSpaceBar(
                background:
                    images.isEmpty
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
                                    80,
                                color:
                                    AppColors.secondary,
                              ),
                            ),
                          )
                        : Stack(
                            fit:
                                StackFit.expand,
                            children: [
                              PageView.builder(
                                itemCount:
                                    images.length,
                                onPageChanged:
                                    (index) {
                                  setState(
                                    () {
                                      currentImageIndex =
                                          index;
                                    },
                                  );
                                },
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  return Image.network(
                                    images[
                                        index],
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
                                                64,
                                            color:
                                                AppColors.secondary,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),

                              if (images.length >
                                  1)
                                Positioned(
                                  bottom:
                                      16,
                                  right:
                                      16,
                                  child:
                                      Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal:
                                          12,
                                      vertical:
                                          7,
                                    ),
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          Colors.black54,
                                      borderRadius:
                                          BorderRadius.circular(
                                        20,
                                      ),
                                    ),
                                    child:
                                        Text(
                                      '${currentImageIndex + 1}/${images.length}',
                                      style:
                                          const TextStyle(
                                        color:
                                            Colors.white,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ),

            SliverPadding(
              padding:
                  const EdgeInsets.all(
                24,
              ),
              sliver:
                  SliverList(
                delegate:
                    SliverChildListDelegate(
                  [
                    Text(
                      widget.property[
                              'title'] ??
                          'Sin título',
                      style:
                          AppTextStyles
                              .titleLarge,
                    ),

                    const SizedBox(
                      height:
                          10,
                    ),

                    if (location
                        .isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            size:
                                20,
                            color:
                                AppColors.textSecondary,
                          ),

                          const SizedBox(
                            width:
                                6,
                          ),

                          Expanded(
                            child:
                                Text(
                              location,
                              style:
                                  AppTextStyles.bodyMedium,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(
                      height:
                          20,
                    ),

                    Text(
                      '$currency $price / mes',
                      style:
                          const TextStyle(
                        fontSize:
                            24,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.primary,
                      ),
                    ),

                    const SizedBox(
                      height:
                          24,
                    ),

                    Wrap(
                      spacing:
                          10,
                      runSpacing:
                          10,
                      children: [
                        _InfoChip(
                          icon:
                              Icons.home_outlined,
                          label:
                              _propertyTypeLabel(),
                        ),

                        _InfoChip(
                          icon:
                              Icons.key_outlined,
                          label:
                              _rentalTypeLabel(),
                        ),

                        _InfoChip(
                          icon:
                              Icons.bed_outlined,
                          label:
                              '${widget.property['bedrooms'] ?? 0} dormitorio(s)',
                        ),

                        _InfoChip(
                          icon:
                              Icons.bathtub_outlined,
                          label:
                              '${widget.property['bathrooms'] ?? 0} baño(s)',
                        ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          28,
                    ),

                    const Text(
                      'Características',
                      style:
                          AppTextStyles
                              .titleMedium,
                    ),

                    const SizedBox(
                      height:
                          14,
                    ),

                    _FeatureRow(
                      icon:
                          Icons.chair_outlined,
                      label:
                          'Amoblado',
                      value:
                          widget.property[
                                      'furnished'] ==
                                  true
                              ? 'Sí'
                              : 'No',
                    ),

                    const SizedBox(
                      height:
                          12,
                    ),

                    _FeatureRow(
                      icon:
                          Icons.pets_outlined,
                      label:
                          'Acepta mascotas',
                      value:
                          widget.property[
                                      'pets_allowed'] ==
                                  true
                              ? 'Sí'
                              : 'No',
                    ),

                    if (description
                        .isNotEmpty) ...[
                      const SizedBox(
                        height:
                            28,
                      ),

                      const Text(
                        'Descripción',
                        style:
                            AppTextStyles
                                .titleMedium,
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      Text(
                        description,
                        style:
                            AppTextStyles
                                .bodyLarge,
                      ),
                    ],

                    if (address !=
                            null &&
                        address
                            .isNotEmpty) ...[
                      const SizedBox(
                        height:
                            28,
                      ),

                      const Text(
                        'Dirección',
                        style:
                            AppTextStyles
                                .titleMedium,
                      ),

                      const SizedBox(
                        height:
                            12,
                      ),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Icon(
                            Icons
                                .map_outlined,
                            color:
                                AppColors.primary,
                          ),

                          const SizedBox(
                            width:
                                10,
                          ),

                          Expanded(
                            child:
                                Text(
                              address,
                              style:
                                  AppTextStyles.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(
                      height:
                          32,
                    ),

                    const Text(
                      'Publicado por',
                      style:
                          AppTextStyles
                              .titleMedium,
                    ),

                    const SizedBox(
                      height:
                          14,
                    ),

                    if (isLoadingOwner)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical:
                              24,
                        ),
                        child:
                            Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      )
                    else
                      _OwnerCard(
                        avatarUrl:
                            ownerAvatar,
                        displayName:
                            _ownerDisplayName(),
                        typeLabel:
                            _ownerTypeLabel(),
                        isAgency:
                            isAgency,
                        description:
                            ownerDescription,
                        location:
                            ownerLocation,
                        publishedProperties:
                            publishedCount,
                        memberSince:
                            _memberSince(),
                      ),

                    const SizedBox(
                      height:
                          32,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      child:
                          FilledButton.icon(
                        onPressed:
                            isOpeningChat
                                ? null
                                : _openChat,
                        icon:
                            isOpeningChat
                                ? const SizedBox(
                                    width:
                                        20,
                                    height:
                                        20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          AppColors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .chat_bubble_outline,
                                  ),
                        label:
                            Text(
                          isOpeningChat
                              ? 'Abriendo chat...'
                              : 'Contactar',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height:
                          24,
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

class _OwnerCard
    extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final String typeLabel;
  final bool isAgency;
  final String? description;
  final String? location;
  final dynamic publishedProperties;
  final String memberSince;

  const _OwnerCard({
    required this.avatarUrl,
    required this.displayName,
    required this.typeLabel,
    required this.isAgency,
    required this.description,
    required this.location,
    required this.publishedProperties,
    required this.memberSince,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
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
        border:
            Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius:
                    28,
                backgroundColor:
                    AppColors.surface,
                backgroundImage:
                    avatarUrl !=
                                null &&
                            avatarUrl!
                                .isNotEmpty
                        ? NetworkImage(
                            avatarUrl!,
                          )
                        : null,
                child: avatarUrl ==
                            null ||
                        avatarUrl!
                            .isEmpty
                    ? Icon(
                        isAgency
                            ? Icons
                                .business_outlined
                            : Icons
                                .person_outline,
                        color:
                            AppColors.primary,
                      )
                    : null,
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      displayName,
                      style:
                          const TextStyle(
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors
                                .textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      typeLabel,
                      style:
                          AppTextStyles
                              .bodyMedium,
                    ),
                  ],
                ),
              ),

              Icon(
                isAgency
                    ? Icons
                        .business_outlined
                    : Icons
                        .home_outlined,
                color:
                    AppColors.primary,
              ),
            ],
          ),

          if (description !=
                  null &&
              description!
                  .isNotEmpty) ...[
            const SizedBox(
              height:
                  14,
            ),

            Text(
              description!,
              style:
                  AppTextStyles
                      .bodyMedium,
              maxLines:
                  3,
              overflow:
                  TextOverflow
                      .ellipsis,
            ),
          ],

          const SizedBox(
            height:
                14,
          ),

          Wrap(
            spacing:
                14,
            runSpacing:
                10,
            children: [
              if (location !=
                      null &&
                  location!
                      .isNotEmpty)
                _OwnerInfo(
                  icon:
                      Icons
                          .location_on_outlined,
                  text:
                      location!,
                ),

              _OwnerInfo(
                icon:
                    Icons
                        .home_work_outlined,
                text:
                    '$publishedProperties publicadas',
              ),

              if (memberSince
                  .isNotEmpty)
                _OwnerInfo(
                  icon:
                      Icons
                          .calendar_month_outlined,
                  text:
                      'Desde $memberSince',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerInfo
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _OwnerInfo({
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
          size:
              17,
          color:
              AppColors.secondary,
        ),

        const SizedBox(
          width:
              5,
        ),

        Text(
          text,
          style:
              AppTextStyles
                  .bodyMedium,
        ),
      ],
    );
  }
}

class _InfoChip
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            12,
        vertical:
            9,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                18,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            width:
                6,
          ),

          Text(
            label,
            style:
                AppTextStyles
                    .bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _FeatureRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _FeatureRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color:
              AppColors.primary,
        ),

        const SizedBox(
          width:
              12,
        ),

        Expanded(
          child:
              Text(
            label,
            style:
                AppTextStyles
                    .bodyLarge,
          ),
        ),

        Text(
          value,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w600,
            color:
                AppColors
                    .textPrimary,
          ),
        ),
      ],
    );
  }
}