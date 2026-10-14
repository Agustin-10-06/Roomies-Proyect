import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

class OwnerMessagesPage extends StatelessWidget {
  const OwnerMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes'),
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Mensajes',
            style: AppTextStyles.titleLarge,
          ),
        ),
      ),
    );
  }
}