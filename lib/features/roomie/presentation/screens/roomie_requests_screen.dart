import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'roomie_chat_screen.dart';

class RoomieRequestsScreen extends StatefulWidget {
  const RoomieRequestsScreen({
    super.key,
  });

  @override
  State<RoomieRequestsScreen> createState() =>
      _RoomieRequestsScreenState();
}

class _RoomieRequestsScreenState
    extends State<RoomieRequestsScreen> {
  bool isLoading = true;

  List<Map<String, dynamic>> receivedRequests = [];
  List<Map<String, dynamic>> sentRequests = [];

  StreamSubscription<List<Map<String, dynamic>>>?
      _requestsSubscription;

  @override
  void initState() {
    super.initState();

    _loadRequests();
    _listenToRequests();
  }

  void _listenToRequests() {
    final supabase =
        Supabase.instance.client;

    _requestsSubscription = supabase
        .from('roomie_requests')
        .stream(
          primaryKey: ['id'],
        )
        .listen(
      (_) {
        _loadRequests();
      },
      onError: (error) {
        debugPrint(
          'REALTIME ROOMIE REQUESTS SCREEN ERROR: $error',
        );
      },
    );
  }

  Future<void> _loadRequests() async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      return;
    }

    try {
      final results =
          await Future.wait([
        supabase
            .from('roomie_requests')
            .select(
              '''
              id,
              requester_id,
              target_id,
              status,
              message,
              created_at,
              updated_at
              ''',
            )
            .eq(
              'target_id',
              user.id,
            )
            .order(
              'created_at',
              ascending: false,
            ),
        supabase
            .from('roomie_requests')
            .select(
              '''
              id,
              requester_id,
              target_id,
              status,
              message,
              created_at,
              updated_at
              ''',
            )
            .eq(
              'requester_id',
              user.id,
            )
            .order(
              'created_at',
              ascending: false,
            ),
      ]);

      final received =
          List<Map<String, dynamic>>
              .from(
        results[0],
      );

      final sent =
          List<Map<String, dynamic>>
              .from(
        results[1],
      );

      await Future.wait([
        ...received.map(
          (request) =>
              _loadOtherUserData(
            request: request,
            otherUserId:
                request['requester_id']
                    ?.toString(),
          ),
        ),
        ...sent.map(
          (request) =>
              _loadOtherUserData(
            request: request,
            otherUserId:
                request['target_id']
                    ?.toString(),
          ),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        receivedRequests =
            received;

        sentRequests =
            sent;

        isLoading = false;
      });
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
            'No se pudieron cargar las solicitudes: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadOtherUserData({
    required Map<String, dynamic> request,
    required String? otherUserId,
  }) async {
    if (otherUserId == null) {
      request['roomie_profile'] = null;
      return;
    }

    final supabase =
        Supabase.instance.client;

    try {
      final data =
          await supabase.rpc(
        'get_public_roomie_request_profile',
        params: {
          'profile_id':
              otherUserId,
        },
      );

      final rows =
          List<Map<String, dynamic>>
              .from(data);

      request['roomie_profile'] =
          rows.isNotEmpty
              ? rows.first
              : null;
    } catch (error) {
      debugPrint(
        'ERROR REQUEST PROFILE $otherUserId: $error',
      );

      request['roomie_profile'] =
          null;
    }
  }

  Future<void> _updateStatus(
    String requestId,
    String newStatus,
  ) async {
    final supabase =
        Supabase.instance.client;

    try {
      await supabase
          .from('roomie_requests')
          .update({
            'status':
                newStatus,
          })
          .eq(
            'id',
            requestId,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            newStatus ==
                    'accepted'
                ? 'Solicitud aceptada.'
                : 'Solicitud rechazada.',
          ),
        ),
      );

      await _loadRequests();
    } on PostgrestException catch (error) {
      if (!mounted) return;

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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo actualizar la solicitud: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  Future<void> _openRoomieChat(
    Map<String, dynamic> request,
  ) async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    final requestId =
        request['id']
            ?.toString();

    final requesterId =
        request['requester_id']
            ?.toString();

    final targetId =
        request['target_id']
            ?.toString();

    final status =
        request['status']
            ?.toString();

    if (requestId == null ||
        requesterId == null ||
        targetId == null) {
      return;
    }

    if (status != 'accepted') {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'La solicitud tiene que estar aceptada para abrir el chat.',
          ),
        ),
      );

      return;
    }

    final otherUserId =
        user.id == requesterId
            ? targetId
            : requesterId;

    try {
      final existing =
          await supabase
              .from(
                'roomie_conversations',
              )
              .select(
                'id',
              )
              .eq(
                'request_id',
                requestId,
              )
              .maybeSingle();

      String conversationId;

      if (existing != null) {
        conversationId =
            existing['id']
                .toString();
      } else {
        try {
          final created =
              await supabase
                  .from(
                    'roomie_conversations',
                  )
                  .insert({
                    'request_id':
                        requestId,
                    'user_a':
                        requesterId,
                    'user_b':
                        targetId,
                  })
                  .select(
                    'id',
                  )
                  .single();

          conversationId =
              created['id']
                  .toString();
        } on PostgrestException {
          final existingAfterInsert =
              await supabase
                  .from(
                    'roomie_conversations',
                  )
                  .select(
                    'id',
                  )
                  .eq(
                    'request_id',
                    requestId,
                  )
                  .single();

          conversationId =
              existingAfterInsert[
                      'id']
                  .toString();
        }
      }

      String otherUserName =
          request['roomie_profile']
                      ?['full_name']
                  ?.toString() ??
              'Roomie';

      if (otherUserName ==
          'Roomie') {
        try {
          final profile =
              await supabase.rpc(
            'get_public_profile',
            params: {
              'profile_id':
                  otherUserId,
            },
          );

          final rows =
              List<
                  Map<String,
                      dynamic>>.from(
            profile,
          );

          if (rows.isNotEmpty) {
            otherUserName =
                rows.first[
                            'full_name']
                        ?.toString() ??
                    'Roomie';
          }
        } catch (_) {
          // Fallback Roomie.
        }
      }

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RoomieChatScreen(
            conversationId:
                conversationId,
            otherUserName:
                otherUserName,
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

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
    }
  }

  String _formatDate(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    final date =
        DateTime.tryParse(
      value.toString(),
    );

    if (date == null) {
      return '';
    }

    final local =
        date.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    final month =
        local.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '$day/$month/${local.year}';
  }

  @override
  void dispose() {
    _requestsSubscription
        ?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title:
              const Text(
            'Solicitudes',
          ),
          bottom:
              const TabBar(
            tabs: [
              Tab(
                text:
                    'Recibidas',
              ),
              Tab(
                text:
                    'Enviadas',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: isLoading
              ? const Center(
                  child:
                      CircularProgressIndicator(),
                )
              : TabBarView(
                  children: [
                    _RequestsList(
                      requests:
                          receivedRequests,
                      isReceived:
                          true,
                      onRefresh:
                          _loadRequests,
                      formatDate:
                          _formatDate,
                      onAccept:
                          (
                        request,
                      ) {
                        _updateStatus(
                          request['id']
                              .toString(),
                          'accepted',
                        );
                      },
                      onReject:
                          (
                        request,
                      ) {
                        _updateStatus(
                          request['id']
                              .toString(),
                          'rejected',
                        );
                      },
                      onOpenChat:
                          _openRoomieChat,
                    ),

                    _RequestsList(
                      requests:
                          sentRequests,
                      isReceived:
                          false,
                      onRefresh:
                          _loadRequests,
                      formatDate:
                          _formatDate,
                      onOpenChat:
                          _openRoomieChat,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _RequestsList
    extends StatelessWidget {
  final List<Map<String, dynamic>>
      requests;

  final bool isReceived;

  final Future<void> Function()
      onRefresh;

  final String Function(
    dynamic,
  ) formatDate;

  final void Function(
    Map<String, dynamic>,
  )? onAccept;

  final void Function(
    Map<String, dynamic>,
  )? onReject;

  final void Function(
    Map<String, dynamic>,
  ) onOpenChat;

  const _RequestsList({
    required this.requests,
    required this.isReceived,
    required this.onRefresh,
    required this.formatDate,
    this.onAccept,
    this.onReject,
    required this.onOpenChat,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    if (requests.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            onRefresh,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.all(
            24,
          ),
          children: [
            const SizedBox(
              height: 140,
            ),

            Icon(
              isReceived
                  ? Icons
                      .person_add_alt_1_outlined
                  : Icons
                      .send_outlined,
              size: 64,
              color:
                  AppColors.secondary,
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              isReceived
                  ? 'Todavía no tenés solicitudes recibidas.'
                  : 'Todavía no enviaste solicitudes.',
              textAlign:
                  TextAlign.center,
              style:
                  AppTextStyles
                      .titleMedium,
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              isReceived
                  ? 'Cuando otro Roomie quiera compartir contigo, aparecerá acá.'
                  : 'Cuando quieras compartir con otro Roomie, vas a poder seguir el estado de la solicitud acá.',
              textAlign:
                  TextAlign.center,
              style:
                  AppTextStyles
                      .bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          onRefresh,
      child:
          ListView.separated(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(
          20,
        ),
        itemCount:
            requests.length,
        separatorBuilder:
            (_, __) =>
                const SizedBox(
          height: 12,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final request =
              requests[index];

          return _RequestCard(
            request:
                request,
            formattedDate:
                formatDate(
              request[
                  'created_at'],
            ),
            isReceived:
                isReceived,
            onAccept:
                onAccept == null
                    ? null
                    : () {
                        onAccept!(
                          request,
                        );
                      },
            onReject:
                onReject == null
                    ? null
                    : () {
                        onReject!(
                          request,
                        );
                      },
            onOpenChat: () {
              onOpenChat(
                request,
              );
            },
          );
        },
      ),
    );
  }
}

class _RequestCard
    extends StatelessWidget {
  final Map<String, dynamic>
      request;

  final String formattedDate;

  final bool isReceived;

  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  final VoidCallback onOpenChat;

  const _RequestCard({
    required this.request,
    required this.formattedDate,
    required this.isReceived,
    this.onAccept,
    this.onReject,
    required this.onOpenChat,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final roomieProfile =
        request['roomie_profile'];

    final name =
        roomieProfile?[
                    'full_name']
                ?.toString()
                .trim() ??
            '';

    final occupation =
        roomieProfile?[
                    'occupation']
                ?.toString()
                .trim() ??
            '';

    final zone =
        roomieProfile?[
                    'preferred_zone']
                ?.toString()
                .trim() ??
            '';

    final photoUrl =
        roomieProfile?[
                'profile_photo_url']
            ?.toString();

    final documentationLoaded =
        roomieProfile?[
                'documentation_loaded'] ==
            true;

    final status =
        request['status']
                ?.toString() ??
            'pending';

    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
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
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius:
                    30,
                backgroundColor:
                    AppColors.surface,
                backgroundImage:
                    photoUrl != null &&
                            photoUrl
                                .isNotEmpty
                        ? NetworkImage(
                            photoUrl,
                          )
                        : null,
                child: photoUrl ==
                            null ||
                        photoUrl
                            .isEmpty
                    ? const Icon(
                        Icons.person,
                        color:
                            AppColors.primary,
                      )
                    : null,
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty
                          ? name
                          : 'Roomie',
                      maxLines:
                          1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            17,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppColors.textPrimary,
                      ),
                    ),

                    if (occupation
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .work_outline,
                            size: 16,
                            color:
                                AppColors.textSecondary,
                          ),

                          const SizedBox(
                            width: 5,
                          ),

                          Expanded(
                            child:
                                Text(
                              occupation,
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
                    ],

                    if (zone
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 4,
                      ),

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .location_on_outlined,
                            size: 16,
                            color:
                                AppColors.textSecondary,
                          ),

                          const SizedBox(
                            width: 5,
                          ),

                          Expanded(
                            child:
                                Text(
                              zone,
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
                    ],

                    if (documentationLoaded) ...[
                      const SizedBox(
                        height: 8,
                      ),

                      const _DocumentationBadge(),
                    ],
                  ],
                ),
              ),

              if (formattedDate
                  .isNotEmpty) ...[
                const SizedBox(
                  width: 8,
                ),

                Text(
                  formattedDate,
                  style:
                      const TextStyle(
                    fontSize:
                        12,
                    color:
                        AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          if (status ==
                  'pending' &&
              isReceived)
            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton(
                    onPressed:
                        onReject,
                    child:
                        const Text(
                      'Rechazar',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Expanded(
                  child:
                      FilledButton(
                    onPressed:
                        onAccept,
                    child:
                        const Text(
                      'Aceptar',
                    ),
                  ),
                ),
              ],
            )
          else if (status ==
              'accepted')
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const _StatusChip(
                  status:
                      'accepted',
                ),

                const SizedBox(
                  height: 12,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      FilledButton.icon(
                    onPressed:
                        onOpenChat,
                    icon:
                        const Icon(
                      Icons
                          .chat_bubble_outline,
                    ),
                    label:
                        const Text(
                      'Abrir chat',
                    ),
                  ),
                ),
              ],
            )
          else
            _StatusChip(
              status:
                  status,
            ),
        ],
      ),
    );
  }
}

class _DocumentationBadge
    extends StatelessWidget {
  const _DocumentationBadge();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border:
            Border.all(
          color:
              AppColors.success,
        ),
      ),
      child:
          const Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons
                .check_circle_outline,
            size: 15,
            color:
                AppColors.success,
          ),

          SizedBox(
            width: 5,
          ),

          Text(
            'Documentación cargada',
            style:
                TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip
    extends StatelessWidget {
  final String status;

  const _StatusChip({
    required this.status,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final accepted =
        status ==
            'accepted';

    final rejected =
        status ==
            'rejected';

    final label =
        accepted
            ? 'Aceptada'
            : rejected
                ? 'Rechazada'
                : 'Pendiente';

    final icon =
        accepted
            ? Icons
                .check_circle_outline
            : rejected
                ? Icons
                    .cancel_outlined
                : Icons
                    .schedule_outlined;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.background,
        borderRadius:
            BorderRadius.circular(
          30,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color:
                AppColors.primary,
          ),

          const SizedBox(
            width: 6,
          ),

          Text(
            label,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}