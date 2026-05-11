import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';
import '../utils/error_handler.dart';
import 'service_screen.dart';
import 'master_works_screen.dart';

class MasterScreen extends StatelessWidget {
  const MasterScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchBarbers() async {
    try {
      // ✅ ИСПРАВЛЕНО: убираем raiting_avg из select и order
      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, photo_url, master_rank')
          .eq('role_id', 2)
          .eq('is_active', true)
          .order('created_at', ascending: false); // Сортировка по дате добавления

      final List<Map<String, dynamic>> masters = List<Map<String, dynamic>>.from(response);
      
      // ✅ Если нужен рейтинг — загружаем его отдельно из reviews (опционально)
      // for (var m in masters) {
      //   final reviews = await Supabase.instance.client
      //       .from('reviews')
      //       .select('rating')
      //       .eq('master_id', m['user_id']);
      //   final avg = reviews.isNotEmpty 
      //       ? reviews.map((r) => r['rating'] as int).reduce((a, b) => a + b) / reviews.length 
      //       : 0.0;
      //   m['review_count'] = reviews.length;
      //   m['raiting_avg'] = avg;
      // }
      
      // ✅ Пока добавляем заглушки для совместимости с UI
      for (var m in masters) {
        m['review_count'] = 0;
        m['raiting_avg'] = 0.0;
      }
      
      return masters;
    } on PostgrestException catch (e) {
      ErrorHandler.logError('MasterScreen._fetchBarbers', e);
      rethrow;
    } catch (e) {
      ErrorHandler.logError('MasterScreen._fetchBarbers', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchBarbers(),
        builder: (context, snapshot) {
          // ✅ Обработка ошибок
          if (snapshot.hasError) {
            ErrorHandler.logError('MasterScreen.build', snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить мастеров',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ErrorHandler.getErrorMessage(snapshot.error),
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MasterScreen()),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Попробовать снова'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD47926),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Загрузка
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          // Нет данных
          final barbers = snapshot.data ?? [];
          if (barbers.isEmpty) {
            return const Center(
              child: Text(
                'Нет мастеров',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          // Успех
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            itemCount: barbers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final b = barbers[index];
              return _MasterCard(
                masterId: b['user_id'],
                name: b['full_name'] ?? 'Мастер',
                photoUrl: b['photo_url'],
                rating: (b['raiting_avg'] ?? 0.0).toDouble(),
                reviewCount: b['review_count'] ?? 0,
                position: b['master_rank'] ?? (index == 0 ? 'Основатель' : 'Барбер'),
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

  const _MasterCard({
    required this.masterId,
    required this.name,
    this.photoUrl,
    required this.rating,
    required this.reviewCount,
    required this.position,
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
                      // ✅ Показываем ранг мастера
                      Text(
                        position,
                        style: const TextStyle(color: Color(0xFFD47926), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MasterWorksScreen(
                                masterId: masterId,
                                masterName: name,
                              ),
                            ),
                          );
                        },
                        child: Row(
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
          errorBuilder: (context, error, stackTrace) {
            ErrorHandler.logError('_MasterCard._buildAvatar', error, stackTrace);
            return _buildInitialsAvatar();
          },
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