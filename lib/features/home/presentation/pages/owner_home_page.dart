import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_text_styles.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({super.key});

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  String? name;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('full_name')
        .eq('id', user.id)
        .single();

    if (!mounted) return;

    setState(() {
      name = profile['full_name'] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rommie Match'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name == null ? 'Hola 👋' : 'Hola, $name 👋',
                style: AppTextStyles.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Gestioná tus publicaciones desde acá.',
                style: AppTextStyles.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}