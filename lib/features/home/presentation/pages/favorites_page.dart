import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Tus favoritos',
            style: AppTextStyles.titleLarge,
          ),
        ),
      ),
    );
  }
}