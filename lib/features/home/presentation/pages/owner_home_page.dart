import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../properties/presentation/screens/create_property_screen.dart';

class OwnerHomePage extends StatefulWidget {
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenProperties;

  const OwnerHomePage({
    super.key,
    this.onOpenMessages,
    this.onOpenProperties,
  });

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  bool isLoading = true;

  String? name;

  int unreadMessages = 0;

  List<Map<String, dynamic>> recentProperties = [];

  @override
  void initState() {
    super.initState();

    _loadHome();
  }

  Future<void> _loadHome() async {
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
      final profile = await supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      final properties = await supabase
          .from('properties')
          .select(
            '''
            id,
            title,
            price,
            currency,
            status,
            city,
            neighborhood,
            created_at,
            property_images(
              image_url,
              position
            )
            ''',
          )
          .eq('owner_id', user.id)
          .order(
            'created_at',
            ascending: false,
          )
          .limit(3);

      final conversations = await supabase
          .from('conversations')
          .select('id')
          .eq('owner_id', user.id);

      int unreadCount = 0;

      if (conversations.isNotEmpty) {
        final conversationIds = conversations
            .map(
              (conversation) =>
                  conversation['id'].toString(),
            )
            .toList();

        final unread = await supabase
            .from('messages')
            .select('id')
            .inFilter(
              'conversation_id',
              conversationIds,
            )
            .neq(
              'sender_id',
              user.id,
            )
            .isFilter(
              'read_at',
              null,
            );

        unreadCount = unread.length;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        name = profile?['full_name']?.toString();

        recentProperties =
            List<Map<String, dynamic>>.from(
          properties,
        );

        unreadMessages = unreadCount;

        isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

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
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar el inicio: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openCreateProperty() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CreatePropertyScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadHome();
  }

  String? _propertyImage(
    Map<String, dynamic> property,
  ) {
    final rawImages =
        property['property_images'];

    if (rawImages is! List ||
        rawImages.isEmpty) {
      return null;
    }

    final images =
        List<Map<String, dynamic>>.from(
      rawImages,
    );

    images.sort(
      (a, b) {
        final positionA =
            a['position'] as int? ?? 0;

        final positionB =
            b['position'] as int? ?? 0;

        return positionA.compareTo(
          positionB,
        );
      },
    );

    final imageUrl =
        images.first['image_url']
            ?.toString();

    if (imageUrl == null ||
        imageUrl.isEmpty) {
      return null;
    }

    return imageUrl;
  }

  String _propertyLocation(
    Map<String, dynamic> property,
  ) {
    final neighborhood =
        property['neighborhood']
            ?.toString()
            .trim();

    final city =
        property['city']
            ?.toString()
            .trim();

    if (neighborhood != null &&
        neighborhood.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      return '$neighborhood, $city';
    }

    if (neighborhood != null &&
        neighborhood.isNotEmpty) {
      return neighborhood;
    }

    if (city != null &&
        city.isNotEmpty) {
      return city;
    }

    return 'Ubicación sin definir';
  }

  String _statusLabel(
    String? status,
  ) {
    switch (status) {
      case 'published':
        return 'Publicada';

      case 'draft':
        return 'Borrador';

      case 'paused':
        return 'Pausada';

      case 'rented':
        return 'Alquilada';

      default:
        return 'Sin estado';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rommie Match',
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadHome,
          child: isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.all(24),
                  children: [
                    Text(
                      name == null ||
                              name!
                                  .trim()
                                  .isEmpty
                          ? 'Hola 👋'
                          : 'Hola, $name 👋',
                      style:
                          AppTextStyles.titleLarge,
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    const Text(
                      'Gestioná tus publicaciones desde acá.',
                      style:
                          AppTextStyles.bodyLarge,
                    ),

                    const SizedBox(
                      height: 28,
                    ),

                    _MessagesCard(
                      unreadMessages:
                          unreadMessages,
                      onTap:
                          widget.onOpenMessages,
                    ),

                    const SizedBox(
                      height: 18,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 56,
                      child:
                          FilledButton.icon(
                        onPressed:
                            _openCreateProperty,
                        icon:
                            const Icon(
                          Icons.add_home_outlined,
                        ),
                        label:
                            const Text(
                          'Publicar nueva propiedad',
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 32,
                    ),

                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tus propiedades recientes',
                            style:
                                AppTextStyles.titleMedium,
                          ),
                        ),

                        if (recentProperties
                                .isNotEmpty &&
                            widget.onOpenProperties !=
                                null)
                          TextButton(
                            onPressed:
                                widget.onOpenProperties,
                            child:
                                const Text(
                              'Ver todas',
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    if (recentProperties
                        .isEmpty)
                      _EmptyPropertiesCard(
                        onPublish:
                            _openCreateProperty,
                      )
                    else
                      ...recentProperties.map(
                        (property) {
                          return Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 14,
                            ),
                            child:
                                _RecentPropertyCard(
                              property:
                                  property,
                              imageUrl:
                                  _propertyImage(
                                property,
                              ),
                              location:
                                  _propertyLocation(
                                property,
                              ),
                              statusLabel:
                                  _statusLabel(
                                property['status']
                                    ?.toString(),
                              ),
                            ),
                          );
                        },
                      ),

                    if (recentProperties
                            .isNotEmpty &&
                        widget.onOpenProperties !=
                            null) ...[
                      const SizedBox(
                        height: 4,
                      ),

                      SizedBox(
                        width:
                            double.infinity,
                        child:
                            OutlinedButton.icon(
                          onPressed:
                              widget.onOpenProperties,
                          icon:
                              const Icon(
                            Icons
                                .home_work_outlined,
                          ),
                          label:
                              const Text(
                            'Ver todas mis propiedades',
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 24,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MessagesCard extends StatelessWidget {
  final int unreadMessages;
  final VoidCallback? onTap;

  const _MessagesCard({
    required this.unreadMessages,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasUnread =
        unreadMessages > 0;

    return Material(
      color: AppColors.white,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        onTap: onTap,
        child: Container(
          width:
              double.infinity,
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
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
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: const Icon(
                  Icons
                      .chat_bubble_outline,
                  color:
                      AppColors.primary,
                  size: 26,
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      hasUnread
                          ? 'Tenés $unreadMessages ${unreadMessages == 1 ? 'mensaje' : 'mensajes'} sin leer'
                          : 'No tenés mensajes sin leer',
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      hasUnread
                          ? 'Revisá tus consultas recientes.'
                          : 'Tus mensajes están al día.',
                      style:
                          AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),

              if (onTap != null)
                const Icon(
                  Icons
                      .chevron_right,
                  color:
                      AppColors.secondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPropertyCard
    extends StatelessWidget {
  final Map<String, dynamic> property;
  final String? imageUrl;
  final String location;
  final String statusLabel;

  const _RecentPropertyCard({
    required this.property,
    required this.imageUrl,
    required this.location,
    required this.statusLabel,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final title =
        property['title']
                ?.toString() ??
            'Sin título';

    final price =
        property['price'] ?? 0;

    final currency =
        property['currency']
                ?.toString() ??
            'UYU';

    return Container(
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
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.only(
              topLeft:
                  Radius.circular(
                17,
              ),
              bottomLeft:
                  Radius.circular(
                17,
              ),
            ),
            child:
                SizedBox(
              width: 110,
              height: 115,
              child: imageUrl ==
                      null
                  ? Container(
                      color:
                          AppColors.surface,
                      child:
                          const Icon(
                        Icons
                            .home_work_outlined,
                        size: 38,
                        color:
                            AppColors.secondary,
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit:
                          BoxFit.cover,
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
                              const Icon(
                            Icons
                                .broken_image_outlined,
                            color:
                                AppColors.secondary,
                          ),
                        );
                      },
                    ),
            ),
          ),

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                14,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          AppColors
                              .textPrimary,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Row(
                    children: [
                      const Icon(
                        Icons
                            .location_on_outlined,
                        size: 15,
                        color: AppColors
                            .textSecondary,
                      ),

                      const SizedBox(
                        width: 4,
                      ),

                      Expanded(
                        child:
                            Text(
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
                    height: 7,
                  ),

                  Text(
                    '$currency $price / mes',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      color:
                          AppColors.primary,
                    ),
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
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
                    child: Text(
                      statusLabel,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPropertiesCard
    extends StatelessWidget {
  final VoidCallback onPublish;

  const _EmptyPropertiesCard({
    required this.onPublish,
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
        24,
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
        children: [
          const Icon(
            Icons
                .home_work_outlined,
            size: 44,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            height: 12,
          ),

          const Text(
            'Todavía no tenés propiedades',
            textAlign:
                TextAlign.center,
            style:
                TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            'Publicá tu primera propiedad para empezar.',
            textAlign:
                TextAlign.center,
            style:
                AppTextStyles.bodyMedium,
          ),

          const SizedBox(
            height: 16,
          ),

          OutlinedButton.icon(
            onPressed:
                onPublish,
            icon:
                const Icon(
              Icons.add,
            ),
            label:
                const Text(
              'Publicar propiedad',
            ),
          ),
        ],
      ),
    );
  }
}