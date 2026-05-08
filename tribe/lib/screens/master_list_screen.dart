import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';
import 'service_screen.dart';

class MasterListScreen extends StatelessWidget {
  final List<int> serviceIds;

  const MasterListScreen({
    super.key,
    required this.serviceIds,
  });

  Future<List<Map<String, dynamic>>> _fetchMasters() async {
    if (serviceIds.isEmpty) return [];

    final barberServicesResponse = await Supabase.instance.client
        .from('barber_services')
        .select('barber_id, service_id');

    if (barberServicesResponse.isEmpty) return [];

    final Map<String, int> barberCounts = {};
    for (final row in barberServicesResponse) {
      final barberId = row['barber_id'].toString();
      final serviceId = row['service_id'] as int;
      if (serviceIds.contains(serviceId)) {
        barberCounts[barberId] = (barberCounts[barberId] ?? 0) + 1;
      }
    }

    final List<String> qualifiedBarberIds = barberCounts.entries
        .where((entry) => entry.value == serviceIds.length)
        .map((entry) => entry.key)
        .toList();

    if (qualifiedBarberIds.isEmpty) return [];

    final mastersResponse = await Supabase.instance.client
        .from('users')
        .select('user_id, full_name, raiting_avg, photo_url')
        .inFilter('user_id', qualifiedBarberIds)
        .eq('role_id', 2);

    final List<Map<String, dynamic>> masters = List<Map<String, dynamic>>.from(mastersResponse);
    for (var m in masters) {
      m['review_count'] = 31;
    }
    return masters;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMasters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final masters = snapshot.data ?? [];
          if (masters.isEmpty) {
            return const Center(
              child: Text(
                'Нет мастеров для выбранных услуг',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            itemCount: masters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = masters[index];
              return _MasterCard(
                masterId: m['user_id'],
                name: m['full_name'] ?? 'Мастер',
                photoUrl: m['photo_url'],
                rating: (m['raiting_avg'] ?? 0.0).toDouble(),
                reviewCount: m['review_count'] ?? 0,
                position: index == 0 ? 'Основатель' : 'Барбер',
                serviceIds: serviceIds,
              );
            },
          );
        },
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  final String masterId;
  final String name;
  final String? photoUrl;
  final double rating;
  final int reviewCount;
  final String position;
  final List<int> serviceIds;

  const _MasterCard({
    required this.masterId,
    required this.name,
    this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.position,
    required this.serviceIds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServiceScreen(
                  barberId: masterId,
                  masterName: name,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        position,
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ...List.generate(5, (i) => Icon(
                                i < rating.floor() ? Icons.star : Icons.star_border,
                                color: const Color(0xFFD4AF37),
                                size: 14,
                              )),
                          const SizedBox(width: 8),
                          Text(
                            '$reviewCount отзывов',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 56,
              height: 56,
              color: const Color(0xFF555555),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
        ),
      );
    }
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF555555),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}