import 'package:flutter/material.dart';

import 'register_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? selectedRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Cómo querés usar Rommie Match?',
                style: AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 12),

              const Text(
                'Elegí la opción que mejor te representa. Podrás completar tu perfil después.',
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 32),

              _RoleCard(
                title: 'Busco hogar / Roomie',
                description: 'Encontrá alquileres, habitaciones y personas compatibles para compartir vivienda.',
                icon: Icons.people_alt_outlined,
                selected: selectedRole == 'roomie',
                onTap: () {
                  setState(() {
                    selectedRole = 'roomie';
                  });
                },
              ),

              const SizedBox(height: 16),

              _RoleCard(
                title: 'Propietario / Inmobiliaria',
                description: 'Publicá y gestioná casas, apartamentos o habitaciones disponibles.',
                icon: Icons.home_work_outlined,
                selected: selectedRole == 'owner',
                onTap: () {
                  setState(() {
                    selectedRole = 'owner';
                  });
                },
              ),

              const Spacer(),

              FilledButton(
                onPressed: selectedRole == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(role: selectedRole!),
                          ),
                        );
                      },
                child: const Text('Continuar', style: AppTextStyles.button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.neutral,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(description, style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.neutral,
            ),
          ],
        ),
      ),
    );
  }
}
