import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RoomieChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;

  const RoomieChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
  });

  @override
  State<RoomieChatScreen> createState() =>
      _RoomieChatScreenState();
}

class _RoomieChatScreenState
    extends State<RoomieChatScreen> {
  final _messageController =
      TextEditingController();

  final _scrollController =
      ScrollController();

  final List<Map<String, dynamic>>
      messages = [];

  StreamSubscription<
      List<Map<String, dynamic>>>?
      _messagesSubscription;

  bool isLoading = true;
  bool isSending = false;

  @override
  void initState() {
    super.initState();

    _loadMessages();
    _listenToMessages();
    _markMessagesAsRead();
  }

  Future<void> _loadMessages() async {
    final supabase =
        Supabase.instance.client;

    try {
      final data = await supabase
          .from('roomie_messages')
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
            List<Map<String, dynamic>>
                .from(data),
          );

        isLoading = false;
      });

      _scrollToBottom();
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
    }
  }

  void _listenToMessages() {
    final supabase =
        Supabase.instance.client;

    _messagesSubscription = supabase
        .from('roomie_messages')
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

        setState(() {
          messages
            ..clear()
            ..addAll(
              List<Map<String, dynamic>>
                  .from(data),
            );
        });

        _markMessagesAsRead();
        _scrollToBottom();
      },
      onError: (error) {
        debugPrint(
          'REALTIME ROOMIE CHAT ERROR: $error',
        );
      },
    );
  }

  Future<void> _markMessagesAsRead() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) return;

    try {
      await supabase
          .from('roomie_messages')
          .update({
            'read_at': DateTime.now()
                .toUtc()
                .toIso8601String(),
          })
          .eq(
            'conversation_id',
            widget.conversationId,
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
      // No bloqueamos el chat si falla.
    }
  }

  Future<void> _sendMessage() async {
    final content =
        _messageController.text.trim();

    if (content.isEmpty || isSending) {
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
      await supabase
          .from('roomie_messages')
          .insert({
        'conversation_id':
            widget.conversationId,
        'sender_id':
            user.id,
        'content':
            content,
      });

      _messageController.clear();

      _scrollToBottom();
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text(error.message),
          backgroundColor:
              AppColors.error,
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

  void _scrollToBottom() {
    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  String _formatTime(dynamic value) {
    if (value == null) return '';

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) return '';

    final local =
        date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messagesSubscription
        ?.cancel();

    _messageController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        Supabase.instance.client.auth
            .currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.otherUserName,
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
                              30,
                            ),
                            child: Column(
                              mainAxisSize:
                                  MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons
                                      .forum_outlined,
                                  size: 56,
                                  color:
                                      AppColors.secondary,
                                ),
                                SizedBox(
                                  height: 14,
                                ),
                                Text(
                                  'Todavía no hay mensajes.',
                                  style:
                                      AppTextStyles
                                          .titleMedium,
                                ),
                                SizedBox(
                                  height: 6,
                                ),
                                Text(
                                  'Escribile para empezar a coordinar.',
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
                              (
                            context,
                            index,
                          ) {
                            final message =
                                messages[index];

                            final isMine =
                                message[
                                        'sender_id'] ==
                                    currentUserId;

                            return _RoomieMessageBubble(
                              message:
                                  message[
                                              'content']
                                          ?.toString() ??
                                      '',
                              time:
                                  _formatTime(
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
                color:
                    AppColors.white,
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
                    onPressed:
                        isSending
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

class _RoomieMessageBubble
    extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;

  const _RoomieMessageBubble({
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