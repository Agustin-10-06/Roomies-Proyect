import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'chat_screen.dart';

class RoomieMessagesPage extends StatefulWidget {
  const RoomieMessagesPage({super.key});

  @override
  State<RoomieMessagesPage> createState() =>
      _RoomieMessagesPageState();
}

class _RoomieMessagesPageState extends State<RoomieMessagesPage> {
  bool isLoading = true;

  List<Map<String, dynamic>> conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final data = await supabase
          .from('conversations')
          .select('''
            id,
            property_id,
            roomie_id,
            owner_id,
            created_at,
            properties (
              title,
              property_images (
                image_url,
                position
              )
            )
          ''')
          .eq('roomie_id', user.id)
          .order('created_at', ascending: false);

      final loaded =
          List<Map<String, dynamic>>.from(data);

      for (final conversation in loaded) {
        final ownerId =
            conversation['owner_id']?.toString();

        if (ownerId != null) {
          try {
            final profile = await supabase
                .rpc(
                  'get_public_profile',
                  params: {
                    'profile_id': ownerId,
                  },
                )
                .single();

            conversation['owner_profile'] = profile;
          } catch (_) {
            conversation['owner_profile'] = null;
          }
        }

        final conversationId =
            conversation['id']?.toString();

        if (conversationId != null) {
          try {
            final messages = await supabase
                .from('messages')
                .select(
                  'id, content, sender_id, created_at, read_at',
                )
                .eq(
                  'conversation_id',
                  conversationId,
                )
                .order(
                  'created_at',
                  ascending: false,
                )
                .limit(1);

            conversation['last_message'] =
                messages.isNotEmpty
                    ? messages.first
                    : null;
          } catch (_) {
            conversation['last_message'] = null;
          }

          try {
            final unreadMessages = await supabase
                .from('messages')
                .select('id')
                .eq(
                  'conversation_id',
                  conversationId,
                )
                .neq(
                  'sender_id',
                  user.id,
                )
                .isFilter(
                  'read_at',
                  null,
                );

            conversation['unread_count'] =
                unreadMessages.length;
          } catch (_) {
            conversation['unread_count'] = 0;
          }
        }
      }

      loaded.sort((a, b) {
        final aDate = DateTime.tryParse(
              a['last_message']?['created_at']?.toString() ??
                  a['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate = DateTime.tryParse(
              b['last_message']?['created_at']?.toString() ??
                  b['created_at']?.toString() ??
                  '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        conversations = loaded;
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
            'No se pudieron cargar los mensajes: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markAsRead(
    String conversationId,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    await supabase
        .from('messages')
        .update({
          'read_at':
              DateTime.now().toUtc().toIso8601String(),
        })
        .eq(
          'conversation_id',
          conversationId,
        )
        .neq(
          'sender_id',
          user.id,
        )
        .isFilter(
          'read_at',
          null,
        );
  }

  Future<void> _openConversation(
    Map<String, dynamic> conversation,
  ) async {
    final property =
        conversation['properties'];

    final propertyTitle =
        property?['title']?.toString() ??
            'Propiedad';

    final ownerName =
        conversation['owner_profile']?['full_name']
                ?.toString() ??
            'Propietario';

    final conversationId =
        conversation['id'].toString();

    final ownerId =
        conversation['owner_id'].toString();

    await _markAsRead(
      conversationId,
    );

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversationId,
          propertyTitle: propertyTitle,
          ownerId: ownerId,
          otherUserName: ownerName,
        ),
      ),
    );

    await _loadConversations();
  }

  String _formatTime(String? value) {
    if (value == null) return '';

    final parsed =
        DateTime.tryParse(value);

    if (parsed == null) return '';

    final date =
        parsed.toLocal();

    final now =
        DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    final yesterday =
        now.subtract(
      const Duration(days: 1),
    );

    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Ayer';
    }

    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }

  String? _getPropertyImage(
    Map<String, dynamic> conversation,
  ) {
    final property =
        conversation['properties'];

    final rawImages =
        property?['property_images'];

    if (rawImages is! List ||
        rawImages.isEmpty) {
      return null;
    }

    final images =
        List<Map<String, dynamic>>.from(
      rawImages,
    );

    images.sort(
      (a, b) =>
          (a['position'] as int? ?? 0)
              .compareTo(
        b['position'] as int? ?? 0,
      ),
    );

    return images.first['image_url']
        ?.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis mensajes',
        ),
      ),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : conversations.isEmpty
              ? const Center(
                  child: Padding(
                    padding:
                        EdgeInsets.all(
                      24,
                    ),
                    child: Text(
                      'Todavía no tenés conversaciones.',
                      style:
                          AppTextStyles.bodyMedium,
                      textAlign:
                          TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh:
                      _loadConversations,
                  child:
                      ListView.separated(
                    padding:
                        const EdgeInsets.all(
                      20,
                    ),
                    itemCount:
                        conversations.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 12,
                    ),
                    itemBuilder:
                        (context, index) {
                      final conversation =
                          conversations[index];

                      final property =
                          conversation[
                              'properties'];

                      final owner =
                          conversation[
                              'owner_profile'];

                      final lastMessage =
                          conversation[
                              'last_message'];

                      final unreadCount =
                          conversation[
                                  'unread_count']
                              as int? ??
                              0;

                      final imageUrl =
                          _getPropertyImage(
                        conversation,
                      );

                      final ownerName =
                          owner?['full_name']
                                  ?.toString() ??
                              'Propietario';

                      final propertyTitle =
                          property?['title']
                                  ?.toString() ??
                              'Propiedad';

                      final message =
                          lastMessage?[
                                  'content']
                              ?.toString();

                      final messageDate =
                          lastMessage?[
                                  'created_at']
                              ?.toString() ??
                              conversation[
                                      'created_at']
                                  ?.toString();

                      return Material(
                        color:
                            AppColors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                        child: InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),
                          onTap: () {
                            _openConversation(
                              conversation,
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(
                              14,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    14,
                                  ),
                                  child:
                                      SizedBox(
                                    width: 70,
                                    height: 70,
                                    child: imageUrl ==
                                            null
                                        ? Container(
                                            color:
                                                AppColors.surface,
                                            child:
                                                const Icon(
                                              Icons.home_work_outlined,
                                              color:
                                                  AppColors.primary,
                                            ),
                                          )
                                        : Image.network(
                                            imageUrl,
                                            fit:
                                                BoxFit.cover,
                                          ),
                                  ),
                                ),

                                const SizedBox(
                                  width: 14,
                                ),

                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                Text(
                                              ownerName,
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    16,
                                                fontWeight:
                                                    unreadCount > 0
                                                        ? FontWeight.w800
                                                        : FontWeight.w700,
                                              ),
                                            ),
                                          ),

                                          Text(
                                            _formatTime(
                                              messageDate,
                                            ),
                                            style:
                                                AppTextStyles.bodyMedium,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(
                                        height: 4,
                                      ),

                                      Text(
                                        propertyTitle,
                                        maxLines:
                                            1,
                                        overflow:
                                            TextOverflow.ellipsis,
                                        style:
                                            AppTextStyles.bodyMedium,
                                      ),

                                      const SizedBox(
                                        height: 7,
                                      ),

                                      Row(
                                        children: [
                                          Expanded(
                                            child:
                                                Text(
                                              message ??
                                                  'Nueva conversación',
                                              maxLines:
                                                  1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    13,
                                                fontWeight:
                                                    unreadCount > 0
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                color:
                                                    AppColors.textSecondary,
                                              ),
                                            ),
                                          ),

                                          if (unreadCount >
                                              0)
                                            Container(
                                              margin:
                                                  const EdgeInsets.only(
                                                left:
                                                    10,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal:
                                                    7,
                                                vertical:
                                                    4,
                                              ),
                                              decoration:
                                                  const BoxDecoration(
                                                color:
                                                    AppColors.primary,
                                                shape:
                                                    BoxShape.circle,
                                              ),
                                              child:
                                                  Text(
                                                unreadCount >
                                                        99
                                                    ? '99+'
                                                    : '$unreadCount',
                                                style:
                                                    const TextStyle(
                                                  color:
                                                      AppColors.white,
                                                  fontSize:
                                                      11,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                              ),
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
                    },
                  ),
                ),
    );
  }
}