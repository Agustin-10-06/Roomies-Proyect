import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RoomieVerificationScreen extends StatefulWidget {
  const RoomieVerificationScreen({
    super.key,
  });

  @override
  State<RoomieVerificationScreen> createState() =>
      _RoomieVerificationScreenState();
}

class _RoomieVerificationScreenState
    extends State<RoomieVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? idFront;
  XFile? idBack;
  XFile? selfie;

  bool isLoading = true;
  bool isSubmitting = false;

  String status = 'not_started';

  String? rejectionReason;

  @override
  void initState() {
    super.initState();

    _loadVerification();
  }

  Future<void> _loadVerification() async {
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
      final data = await supabase
          .from(
            'roomie_verifications',
          )
          .select(
            '''
            status,
            rejection_reason,
            id_front_path,
            id_back_path,
            selfie_path
            ''',
          )
          .eq(
            'user_id',
            user.id,
          )
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        status =
            data?['status']
                    ?.toString() ??
                'not_started';

        rejectionReason =
            data?['rejection_reason']
                ?.toString();

        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo cargar la documentación: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    }
  }

  Future<XFile?> _pickImage({
    required ImageSource source,
    CameraDevice preferredCameraDevice =
        CameraDevice.rear,
  }) async {
    return _picker.pickImage(
      source: source,
      preferredCameraDevice:
          preferredCameraDevice,
      imageQuality: 85,
      maxWidth: 1600,
    );
  }

  Future<void> _selectIdFront() async {
    final file =
        await _pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          CameraDevice.rear,
    );

    if (file == null) return;

    setState(() {
      idFront = file;
    });
  }

  Future<void> _selectIdBack() async {
    final file =
        await _pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          CameraDevice.rear,
    );

    if (file == null) return;

    setState(() {
      idBack = file;
    });
  }

  Future<void> _selectSelfie() async {
    final file =
        await _pickImage(
      source: ImageSource.camera,
      preferredCameraDevice:
          CameraDevice.front,
    );

    if (file == null) return;

    setState(() {
      selfie = file;
    });
  }

  Future<String> _uploadFile({
    required XFile file,
    required String name,
  }) async {
    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Usuario no autenticado.',
      );
    }

    final extension =
        file.path
            .split('.')
            .last
            .toLowerCase();

    final path =
        '${user.id}/$name.$extension';

    await supabase.storage
        .from(
          'roomie-verification',
        )
        .upload(
          path,
          File(file.path),
          fileOptions:
              const FileOptions(
            upsert: true,
          ),
        );

    return path;
  }

  Future<void>
      _submitDocumentation() async {
    if (idFront == null ||
        idBack == null ||
        selfie == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Tenés que cargar el frente y dorso de la cédula y una selfie.',
          ),
        ),
      );

      return;
    }

    final supabase =
        Supabase.instance.client;

    final user =
        supabase.auth.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      final idFrontPath =
          await _uploadFile(
        file: idFront!,
        name: 'id_front',
      );

      final idBackPath =
          await _uploadFile(
        file: idBack!,
        name: 'id_back',
      );

      final selfiePath =
          await _uploadFile(
        file: selfie!,
        name: 'selfie',
      );

      final submittedAt =
          DateTime.now()
              .toUtc()
              .toIso8601String();

      await supabase
          .from(
            'roomie_verifications',
          )
          .upsert({
        'user_id':
            user.id,

        'status':
            'pending',

        'id_front_path':
            idFrontPath,

        'id_back_path':
            idBackPath,

        'selfie_path':
            selfiePath,

        'submitted_at':
            submittedAt,

        'rejection_reason':
            null,
      });

      await supabase.rpc(
        'approve_uploaded_roomie_documents',
      );

      if (!mounted) return;

      setState(() {
        status = 'approved';
        rejectionReason = null;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Documentación cargada correctamente.',
          ),
        ),
      );
    } on StorageException catch (error) {
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
            'No se pudo confirmar la documentación: $error',
          ),
          backgroundColor:
              AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  String _statusText() {
    switch (status) {
      case 'pending':
        return 'Documentación pendiente';

      case 'approved':
        return 'Documentación cargada';

      case 'rejected':
        return 'Documentación rechazada';

      default:
        return 'Documentación no cargada';
    }
  }

  IconData _statusIcon() {
    switch (status) {
      case 'pending':
        return Icons.schedule_outlined;

      case 'approved':
        return Icons.check_circle_outline;

      case 'rejected':
        return Icons.cancel_outlined;

      default:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final canSubmit =
        status != 'approved';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Documentación',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding:
              const EdgeInsets.all(
            20,
          ),
          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration: BoxDecoration(
                color:
                    AppColors.surface,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIcon(),
                    size: 30,
                    color:
                        status ==
                                'approved'
                            ? AppColors.success
                            : AppColors.primary,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Text(
                          'Estado',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),

                        const SizedBox(
                          height: 3,
                        ),

                        Text(
                          _statusText(),
                          style:
                              AppTextStyles
                                  .bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (status ==
                    'rejected' &&
                rejectionReason !=
                    null &&
                rejectionReason!
                    .isNotEmpty) ...[
              const SizedBox(
                height: 12,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.background,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Text(
                  'Motivo: $rejectionReason',
                  style:
                      AppTextStyles
                          .bodyMedium,
                ),
              ),
            ],

            const SizedBox(
              height: 28,
            ),

            Text(
              'Carga de documentación',
              style:
                  AppTextStyles
                      .titleMedium,
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Para completar tu perfil necesitamos una foto del frente y dorso de tu cédula y una selfie.',
              style: TextStyle(
                color:
                    AppColors
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'En esta versión de Rommie solo confirmamos que la documentación haya sido cargada correctamente. No validamos automáticamente la autenticidad del documento.',
              style: TextStyle(
                fontSize: 12,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Las imágenes son privadas y no serán visibles para otros Roomies.',
              style: TextStyle(
                fontSize: 12,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            _VerificationItem(
              title:
                  'Cédula - frente',
              subtitle:
                  'Sacá una foto clara del frente de tu cédula.',
              selected:
                  idFront != null,
              enabled:
                  canSubmit,
              icon:
                  Icons.badge_outlined,
              onPressed:
                  _selectIdFront,
            ),

            _VerificationItem(
              title:
                  'Cédula - dorso',
              subtitle:
                  'Sacá una foto clara del dorso de tu cédula.',
              selected:
                  idBack != null,
              enabled:
                  canSubmit,
              icon:
                  Icons.badge_outlined,
              onPressed:
                  _selectIdBack,
            ),

            _VerificationItem(
              title:
                  'Selfie',
              subtitle:
                  'Sacate una foto de frente, con buena luz y sin cubrirte el rostro.',
              selected:
                  selfie != null,
              enabled:
                  canSubmit,
              icon:
                  Icons.face_outlined,
              onPressed:
                  _selectSelfie,
            ),

            const SizedBox(
              height: 24,
            ),

            if (status ==
                'approved')
              Container(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.surface,
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline,
                      color:
                          AppColors.success,
                    ),

                    SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        'Tu documentación fue cargada correctamente.',
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                height: 52,
                child:
                    FilledButton.icon(
                  onPressed:
                      isSubmitting
                          ? null
                          : _submitDocumentation,
                  icon: isSubmitting
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
                          Icons
                              .upload_file_outlined,
                        ),
                  label: Text(
                    isSubmitting
                        ? 'Confirmando...'
                        : status ==
                                'rejected'
                            ? 'Cargar nuevamente'
                            : 'Confirmar documentación',
                  ),
                ),
              ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'Asegurate de que las fotos sean claras, completas y legibles.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 12,
                color:
                    AppColors
                        .textSecondary,
              ),
            ),

            const SizedBox(
              height: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationItem
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final IconData icon;
  final VoidCallback onPressed;

  const _VerificationItem({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration: BoxDecoration(
        color:
            AppColors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
              AppColors.surface,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration:
                BoxDecoration(
              color:
                  AppColors.background,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
            ),
            child: Icon(
              selected
                  ? Icons
                      .check_circle_outline
                  : icon,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle,
                  style:
                      AppTextStyles
                          .bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          TextButton(
            onPressed:
                enabled
                    ? onPressed
                    : null,
            child: Text(
              selected
                  ? 'Cambiar'
                  : 'Cargar',
            ),
          ),
        ],
      ),
    );
  }
}