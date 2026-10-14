import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'role_selection_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),

              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset(
                  'assets/images/rommie_logo.jpeg',
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Rommie Match',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 14),

              const Text(
                'Viví tu momento,\nencontrá tu hogar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Encontrá un lugar para vivir o a la persona ideal para compartirlo.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge,
              ),

              const Spacer(flex: 3),

              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen(),
                    ),
                  );
                },
                child: const Text('Comenzar', style: AppTextStyles.button),
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text(
                  '¿Ya tenés cuenta? Iniciar sesión',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
