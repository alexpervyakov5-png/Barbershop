import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/tribe_app_bar.dart';
import '../utils/error_handler.dart';
import '../utils/cache_service.dart';
import 'service_screen.dart';
import 'master_works_screen.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  final CacheService _cache = CacheService();
  List<Map<String, dynamic>>? _cachedMasters;
  DateTime? _cacheTimestamp;

  Future<List<Map<String, dynamic>>> _fetchBarbers() async {
    // 🔥 Проверяем кеш (5 минут)
    if (_cachedMasters != null && 
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < const Duration(minutes: 5)) {
      debugPrint('✅ Masters loaded from memory cache');
      return _cachedMasters!;
    }

    // 🔥 Пробуем загрузить из localStorage
    final cachedData = await _cache.getFromStorage<List>('masters_list');
    if (cachedData != null) {
      debugPrint('✅ Masters loaded from storage cache');
      final masters = List<Map<String, dynamic>>.from(cachedData);
      _cachedMasters = masters;
      _cacheTimestamp = DateTime.now();
      return masters;
    }

    // 🔥 Загружаем с сервера
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, photo_url, master_rank')
          .eq('role_id', 2)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(0, 49)
          .timeout(const Duration(seconds: 10));

      final List<Map<String, dynamic>> masters = List<Map<String, dynamic>>.from(response);
      
      // 🔥 Загружаем реальный рейтинг
      for (var m in masters) {
        final reviews = await Supabase.instance.client
            .from('reviews')
            .select('rating')
            .eq('master_id', m['user_id']);
            
        final avg = reviews.isNotEmpty 
            ? reviews.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / reviews.length 
            : 0.0;
            
        m['review_count'] = reviews.length;
        m['raiting_avg'] = avg;
      }
      
      // 🔥 Сохраняем в кеш
      _cachedMasters = masters;
      _cacheTimestamp = DateTime.now();
      await _cache.set('masters_list', masters, duration: const Duration(minutes: 10));
      
      return masters;
    } catch (e) {
      ErrorHandler.logError('MasterScreen._fetchBarbers', e);
      rethrow;
    }
  }

  void _clearCache() {
    setState(() {
      _cachedMasters = null;
      _cacheTimestamp = null;
    });
    _cache.clear('masters_list');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchBarbers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    const Text(
                      'Не удалось загрузить мастеров',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
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
                        _clearCache();
                        setState(() {});
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

          if (snapshot.connectionState == ConnectionState.waiting && _cachedMasters == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          final barbers = snapshot.data ?? _cachedMasters ?? [];
          if (barbers.isEmpty) {
            return const Center(
              child: Text('Нет мастеров', style: TextStyle(color: Colors.white70)),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _clearCache();
              await _fetchBarbers();
              if (mounted) setState(() {});
            },
            child: ListView.separated(
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
                  position: b['master_rank'] ?? 'Барбер',
                );
              },
            ),
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
                // 🔥 CachedNetworkImage для аватара
                photoUrl != null && photoUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFF555555),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white54,
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => _buildInitialsAvatar(),
                        ),
                      )
                    : _buildInitialsAvatar(),
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
                                canEdit: false,
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