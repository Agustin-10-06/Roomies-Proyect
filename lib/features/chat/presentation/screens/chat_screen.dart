import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String propertyTitle;
  final String ownerId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.propertyTitle,
    required this.ownerId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];

  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;

  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();

    _loadMessages();
    _listenToMessages();
  }

  Future<void> _loadMessages() async {
    final supabase = Supabase.instance.client;

    try {
      final data = await supabase
          .from('messages')
          .select(
            'id, conversation_id, sender_id, content, created_at, read_at',
          )
          .eq(
            'conversation_id',
            widget.conversationId,
          )
          .order(
            'created_at',
            ascending: true,
          );

      if (!mounted) return;

      setState(() {
        messages
          ..clear()
          ..addAll(
            List<Map<String, dynamic>>.from(data),
          );

        isLoading = false;
      });

      _scrollToBottom();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron cargar los mensajes: ${error.message}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
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

  void _listenToMessages() {
    final supabase = Supabase.instance.client;

    _messagesSubscription = supabase
        .from('messages')
        .stream(
          primaryKey: ['id'],
        )
        .eq(
          'conversation_id',
          widget.conversationId,
        )
        .order(
          'created_at',
          ascending: true,
        )
        .listen(
      (data) {
        if (!mounted) return;

        final incoming =
            List<Map<String, dynamic>>.from(data);

        if (incoming.isEmpty) {
          return;
        }

        final existingIds = messages
            .map(
              (message) => message['id'].toString(),
            )
            .toSet();

        bool changed = false;

        for (final message in incoming) {
          final id = message['id'].toString();

          final existingIndex = messages.indexWhere(
            (item) => item['id'].toString() == id,
          );

          if (existingIndex >= 0) {
            messages[existingIndex] = message;
            changed = true;
          } else if (!existingIds.contains(id)) {
            messages.add(message);
            existingIds.add(id);
            changed = true;
          }
        }

        if (!changed) return;

        messages.sort(
          (a, b) {
            final aDate = DateTime.tryParse(
                  a['created_at']?.toString() ?? '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);

            final bDate = DateTime.tryParse(
                  b['created_at']?.toString() ?? '',
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0);

            return aDate.compareTo(bDate);
          },
        );

        setState(() {});

        _scrollToBottom();
      },
      onError: (error) {
        debugPrint(
          'REALTIME CHAT ERROR: $error',
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final message =
        _messageController.text.trim();

    if (message.isEmpty || isSending) {
      return;
    }

    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    setState(() {
      isSending = true;
    });

    try {
      final insertedMessage = await supabase
          .from('messages')
          .insert({
            'conversation_id':
                widget.conversationId,
            'sender_id': user.id,
            'content': message,
          })
          .select(
            'id, conversation_id, sender_id, content, created_at, read_at',
          )
          .single();

      _messageController.clear();

      final insertedId =
          insertedMessage['id'].toString();

      final alreadyExists = messages.any(
        (item) =>
            item['id'].toString() ==
            insertedId,
      );

      if (!alreadyExists && mounted) {
        setState(() {
          messages.add(
            Map<String, dynamic>.from(
              insertedMessage,
            ),
          );
        });
      }

      _scrollToBottom();
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
            'No se pudo enviar el mensaje: $error',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  String _formatMessageTime(
    dynamic value,
  ) {
    if (value == null) return '';

    final date = DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '';

    final localDate =
        date.toLocal();

    final hour = localDate.hour
        .toString()
        .padLeft(2, '0');

    final minute = localDate.minute
        .toString()
        .padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();

    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  AppTextStyles.titleMedium,
            ),
            Text(
              widget.propertyTitle,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding:
                                EdgeInsets.all(
                              32,
                            ),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons
                                      .chat_bubble_outline,
                                  size: 54,
                                  color:
                                      AppColors.secondary,
                                ),
                                SizedBox(
                                  height: 16,
                                ),
                                Text(
                                  'Todavía no hay mensajes.',
                                  style:
                                      AppTextStyles
                                          .titleMedium,
                                ),
                                SizedBox(
                                  height: 8,
                                ),
                                Text(
                                  'Mandá el primer mensaje para consultar por esta propiedad.',
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      AppTextStyles
                                          .bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller:
                              _scrollController,
                          padding:
                              const EdgeInsets.all(
                            16,
                          ),
                          itemCount:
                              messages.length,
                          itemBuilder:
                              (context, index) {
                            final message =
                                messages[index];

                            final isMine =
                                message['sender_id'] ==
                                    currentUserId;

                            return _MessageBubble(
                              message:
                                  message['content']
                                          ?.toString() ??
                                      '',
                              time:
                                  _formatMessageTime(
                                message[
                                    'created_at'],
                              ),
                              isMine:
                                  isMine,
                            );
                          },
                        ),
            ),

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                10,
                16,
                12,
              ),
              decoration:
                  const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(
                    color:
                        AppColors.surface,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller:
                          _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization:
                          TextCapitalization
                              .sentences,
                      onSubmitted: (_) {
                        _sendMessage();
                      },
                      decoration:
                          const InputDecoration(
                        hintText:
                            'Escribí un mensaje...',
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  IconButton.filled(
                    onPressed: isSending
                        ? null
                        : _sendMessage,
                    icon: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  AppColors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send,
                          ),
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

class _MessageBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;

  const _MessageBubble({
    required this.message,
    required this.time,
    required this.isMine,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 290,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? AppColors.primary
              : AppColors.surface,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius.circular(
              18,
            ),
            topRight:
                const Radius.circular(
              18,
            ),
            bottomLeft:
                Radius.circular(
              isMine ? 18 : 4,
            ),
            bottomRight:
                Radius.circular(
              isMine ? 4 : 18,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMine
                    ? AppColors.white
                    : AppColors
                        .textPrimary,
                fontSize: 15,
              ),
            ),

            if (time.isNotEmpty) ...[
              const SizedBox(
                height: 4,
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine
                      ? AppColors.white
                          .withValues(
                          alpha: 0.75,
                        )
                      : AppColors
                          .textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}