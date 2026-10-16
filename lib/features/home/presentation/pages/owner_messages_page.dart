import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../chat/presentation/screens/chat_screen.dart';

class OwnerMessagesPage extends StatefulWidget {
  const OwnerMessagesPage({super.key});

  @override
  State<OwnerMessagesPage> createState() =>
      _OwnerMessagesPageState();
}

class _OwnerMessagesPageState extends State<OwnerMessagesPage> {
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
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

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
          .eq(
            'owner_id',
            user.id,
          )
          .order(
            'created_at',
            ascending: false,
          );

      final loaded =
          List<Map<String, dynamic>>.from(data);

      for (final conversation in loaded) {
        final roomieId =
            conversation['roomie_id']?.toString();

        if (roomieId != null) {
          try {
            final profile = await supabase
                .rpc(
                  'get_public_profile',
                  params: {
                    'profile_id': roomieId,
                  },
                )
                .single();

            conversation['roomie_profile'] = profile;
          } catch (_) {
            conversation['roomie_profile'] = null;
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

            if (messages.isNotEmpty) {
              conversation['last_message'] =
                  messages.first;
            } else {
              conversation['last_message'] = null;
            }
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
        final aLastMessage = a['last_message'];
        final bLastMessage = b['last_message'];

        final aDateString =
            aLastMessage?['created_at'] ??
                a['created_at'];

        final bDateString =
            bLastMessage?['created_at'] ??
                b['created_at'];

        final aDate =
            DateTime.tryParse(
              aDateString?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        final bDate =
            DateTime.tryParse(
              bDateString?.toString() ?? '',
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        conversations = loaded;
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
            'No se pudieron cargar las conversaciones: $error',
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

  String? _getPropertyImage(
    Map<String, dynamic> conversation,
  ) {
    final property = conversation['properties'];

    if (property == null) return null;

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

    return images.first['image_url']?.toString();
  }

  Future<void> _markConversationAsRead(
    String conversationId,
  ) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    try {
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
    } catch (_) {
      // No bloqueamos la apertura del chat
      // si falla el marcado como leído.
    }
  }

  Future<void> _openConversation(
    Map<String, dynamic> conversation,
  ) async {
    final property =
        conversation['properties'];

    final propertyTitle =
        property?['title']?.toString() ??
            'Propiedad';

    final ownerId =
        conversation['owner_id'].toString();

    final conversationId =
        conversation['id'].toString();

    final roomieName =
        conversation['roomie_profile']
                    ?['full_name']
                ?.toString() ??
            'Roomie';

    await _markConversationAsRead(
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
          otherUserName: roomieName,
        ),
      ),
    );

    await _loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mensajes',
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });

              _loadConversations();
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
            : conversations.isEmpty
                ? RefreshIndicator(
                    onRefresh:
                        _loadConversations,
                    child: ListView(
                      physics:
                          const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      children: const [
                        SizedBox(
                          height: 150,
                        ),
                        Icon(
                          Icons
                              .chat_bubble_outline,
                          size: 64,
                          color:
                              AppColors.secondary,
                        ),
                        SizedBox(
                          height: 20,
                        ),
                        Text(
                          'Todavía no tenés conversaciones.',
                          textAlign:
                              TextAlign.center,
                          style:
                              AppTextStyles.titleMedium,
                        ),
                        SizedBox(
                          height: 8,
                        ),
                        Text(
                          'Cuando alguien consulte por una propiedad, el chat aparecerá acá.',
                          textAlign:
                              TextAlign.center,
                          style:
                              AppTextStyles.bodyMedium,
                        ),
                      ],
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
                          (_, _) {
                        return const SizedBox(
                          height: 12,
                        );
                      },
                      itemBuilder:
                          (context, index) {
                        final conversation =
                            conversations[index];

                        return _ConversationCard(
                          conversation:
                              conversation,
                          imageUrl:
                              _getPropertyImage(
                            conversation,
                          ),
                          onTap: () {
                            _openConversation(
                              conversation,
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

class _ConversationCard extends StatelessWidget {
  final Map<String, dynamic> conversation;
  final String? imageUrl;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.imageUrl,
    required this.onTap,
  });

  String _formatTime(String? value) {
    if (value == null) return '';

    final parsed = DateTime.tryParse(value);

    if (parsed == null) return '';

    final date = parsed.toLocal();
    final now = DateTime.now();

    final isToday =
        date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (isToday) {
      final hour =
          date.hour.toString().padLeft(2, '0');

      final minute =
          date.minute.toString().padLeft(2, '0');

      return '$hour:$minute';
    }

    final yesterday =
        now.subtract(
      const Duration(days: 1),
    );

    final isYesterday =
        date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;

    if (isYesterday) {
      return 'Ayer';
    }

    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final property =
        conversation['properties'];

    final profile =
        conversation['roomie_profile'];

    final lastMessage =
        conversation['last_message'];

    final propertyTitle =
        property?['title']?.toString() ??
            'Propiedad';

    final roomieName =
        profile?['full_name']?.toString() ??
            'Roomie';

    final message =
        lastMessage?['content']?.toString();

    final messageDate =
        lastMessage?['created_at']?.toString() ??
            conversation['created_at']?.toString();

    final unreadCount =
        conversation['unread_count'] as int? ?? 0;

    final hasUnread =
        unreadCount > 0;

    return Material(
      color: AppColors.white,
      borderRadius:
          BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl == null
                      ? Container(
                          color:
                              AppColors.surface,
                          child:
                              const Icon(
                            Icons
                                .home_work_outlined,
                            color:
                                AppColors.primary,
                            size: 34,
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
                              child:
                                  const Icon(
                                Icons
                                    .home_work_outlined,
                                color:
                                    AppColors.primary,
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(
                width: 14,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            roomieName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  hasUnread
                                      ? FontWeight
                                          .w800
                                      : FontWeight
                                          .w700,
                              color:
                                  AppColors
                                      .textPrimary,
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 8,
                        ),

                        Text(
                          _formatTime(
                            messageDate,
                          ),
                          style:
                              TextStyle(
                            fontSize: 12,
                            fontWeight:
                                hasUnread
                                    ? FontWeight
                                        .w700
                                    : FontWeight
                                        .w400,
                            color: hasUnread
                                ? AppColors
                                    .primary
                                : AppColors
                                    .textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      propertyTitle,
                      maxLines: 1,
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
                          child: Text(
                            message ??
                                'Nueva consulta por esta propiedad',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  hasUnread
                                      ? FontWeight
                                          .w700
                                      : FontWeight
                                          .w400,
                              color: hasUnread
                                  ? AppColors
                                      .textPrimary
                                  : AppColors
                                      .textSecondary,
                            ),
                          ),
                        ),

                        if (hasUnread) ...[
                          const SizedBox(
                            width: 10,
                          ),

                          Container(
                            constraints:
                                const BoxConstraints(
                              minWidth: 22,
                              minHeight: 22,
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            decoration:
                                const BoxDecoration(
                              color:
                                  AppColors.primary,
                              shape:
                                  BoxShape.circle,
                            ),
                            alignment:
                                Alignment.center,
                            child: Text(
                              unreadCount > 99
                                  ? '99+'
                                  : '$unreadCount',
                              style:
                                  const TextStyle(
                                color:
                                    AppColors.white,
                                fontSize: 11,
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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