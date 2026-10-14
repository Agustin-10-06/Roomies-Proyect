import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

class RoomiesPage extends StatelessWidget {
  const RoomiesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roomies'),
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Buscar roomies',
            style: AppTextStyles.titleLarge,
          ),
        ),
      ),
    );
  }
}