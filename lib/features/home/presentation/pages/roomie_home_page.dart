import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RoomieHomePage extends StatefulWidget {
  const RoomieHomePage({super.key});

  @override
  State<RoomieHomePage> createState() => _RoomieHomePageState();
}

class _RoomieHomePageState extends State<RoomieHomePage> {
  String? userName;
  bool isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        return;
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        userName = profile['full_name'] as String?;
      });
    } catch (_) {
      // Por ahora dejamos un fallback silencioso.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (userName?.trim().isNotEmpty ?? false)
        ? userName!.trim().split(' ').first
        : 'Roomie';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isLoadingName ? 'Hola 👋' : 'Hola, $firstName 👋',
                style: AppTextStyles.titleLarge,
              ),

              const SizedBox(height: 8),

              const Text(
                '¿Qué estás buscando hoy?',
                style: AppTextStyles.bodyLarge,
              ),

              const SizedBox(height: 24),

              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Buscar alquileres, zonas...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.tune),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Propiedades recomendadas',
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 8),

                  TextButton(onPressed: () {}, child: const Text('Ver todas')),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 285,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    return _PropertyCard(index: index);
                  },
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Roomies sugeridos',
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(width: 8),

                  TextButton(onPressed: () {}, child: const Text('Ver todos')),
                ],
              ),

              const SizedBox(height: 16),

              const _RoomieCard(
                name: 'Agustín',
                age: 24,
                description: 'Busca compartir apartamento en Montevideo.',
              ),

              const SizedBox(height: 12),

              const _RoomieCard(
                name: 'Lucía',
                age: 26,
                description: 'Busca roomie para Cordón o Parque Rodó.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final int index;

  const _PropertyCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final properties = [
      {
        'title': 'Apartamento en Cordón',
        'zone': 'Cordón, Montevideo',
        'price': '\$ 28.000 / mes',
      },
      {
        'title': 'Habitación en Pocitos',
        'zone': 'Pocitos, Montevideo',
        'price': '\$ 15.500 / mes',
      },
      {
        'title': 'Apartamento en Centro',
        'zone': 'Centro, Montevideo',
        'price': '\$ 31.000 / mes',
      },
    ];

    final property = properties[index];

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 155,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.favorite_border,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property['title']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        property['zone']!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Text(
                  property['price']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomieCard extends StatelessWidget {
  final String name;
  final int age;
  final String description;

  const _RoomieCard({
    required this.name,
    required this.age,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.surface,
            child: Icon(Icons.person, color: AppColors.primary),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name, $age',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),

          const Icon(Icons.chevron_right, color: AppColors.primary),
        ],
      ),
    );
  }
}
