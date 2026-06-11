import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';
import '../../utils/review_status.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  List<Map<String, dynamic>> _reviews = [];
  Map<String, Map<String, dynamic>> _usersCache = {}; // Кеш пользователей
  bool _isLoading = true;
  int _reviewFilter = ReviewStatus.pending;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  // ✅ ЗАГРУЗКА ОТЗЫВОВ - разбита на 2 простых запроса
  Future<void> _loadReviews({int retryCount = 0}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ШАГ 1: Получаем отзывы (без связей - простой запрос)
      debugPrint('📋 Loading reviews...');
      List<dynamic> reviewsResponse;
      
      if (_reviewFilter == 0) {
        reviewsResponse = await Supabase.instance.client
            .from('reviews')
            .select('review_id, rating, comment, status_id, created_at, master_id, client_id')
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 60));
      } else {
        reviewsResponse = await Supabase.instance.client
            .from('reviews')
            .select('review_id, rating, comment, status_id, created_at, master_id, client_id')
            .eq('status_id', _reviewFilter)
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 60));
      }

      debugPrint('✅ Reviews loaded: ${reviewsResponse.length}');

      if (reviewsResponse.isEmpty) {
        if (mounted) {
          setState(() {
            _reviews = [];
            _isLoading = false;
          });
        }
        return;
      }

      // ШАГ 2: Собираем все ID пользователей (мастеров и клиентов)
      final userIds = <String>{};
      for (var review in reviewsResponse) {
        if (review['master_id'] != null) userIds.add(review['master_id'].toString());
        if (review['client_id'] != null) userIds.add(review['client_id'].toString());
      }

      debugPrint('👥 Loading ${userIds.length} users...');

      // ШАГ 3: Загружаем пользователей одним запросом (используем in фильтр)
      if (userIds.isNotEmpty) {
        final usersResponse = await Supabase.instance.client
            .from('users')
            .select('user_id, full_name, photo_url')
            .inFilter('user_id', userIds.toList())
            .timeout(const Duration(seconds: 60));

        // Кеш пользователей
        _usersCache = {
          for (var user in usersResponse) user['user_id'].toString(): {
            'full_name': user['full_name'],
            'photo_url': user['photo_url'],
          }
        };
        debugPrint('✅ Users loaded: ${_usersCache.length}');
      }

      // ШАГ 4: Собираем финальный список отзывов с данными пользователей
      final reviews = reviewsResponse.map<Map<String, dynamic>>((review) {
        final masterId = review['master_id']?.toString() ?? '';
        final clientId = review['client_id']?.toString() ?? '';
        
        return {
          ...review,
          'master': _usersCache[masterId] ?? {'full_name': 'Мастер', 'photo_url': null},
          'client': _usersCache[clientId] ?? {'full_name': 'Клиент', 'photo_url': null},
        };
      }).toList();

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoading = false;
        });
      }
    } on SocketException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._loadReviews (Socket)', e);
      if (retryCount < 3 && mounted) {
        debugPrint('🔄 Retry ${retryCount + 1}/3');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _loadReviews(retryCount: retryCount + 1);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _showNetworkError();
      }
    } on TimeoutException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._loadReviews (Timeout)', e);
      if (retryCount < 3 && mounted) {
        debugPrint('🔄 Retry ${retryCount + 1}/3');
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _loadReviews(retryCount: retryCount + 1);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        _showNetworkError();
      }
    } catch (e) {
      ErrorHandler.logError('AdminProfileScreen._loadReviews', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _approveReview(int reviewId, {int retryCount = 0}) async {
    try {
      await Supabase.instance.client
          .from('reviews')
          .update({'status_id': ReviewStatus.published})
          .eq('review_id', reviewId)
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Отзыв опубликован'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReviews();
      }
    } on SocketException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._approveReview (Socket)', e);
      if (retryCount < 3 && mounted) {
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _approveReview(reviewId, retryCount: retryCount + 1);
      }
      if (mounted) _showNetworkError();
    } on TimeoutException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._approveReview (Timeout)', e);
      if (retryCount < 3 && mounted) {
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _approveReview(reviewId, retryCount: retryCount + 1);
      }
      if (mounted) _showNetworkError();
    } catch (e) {
      ErrorHandler.logError('AdminProfileScreen._approveReview', e);
      if (mounted) {
        String message = 'Ошибка: $e';
        if (e.toString().contains('permission') || e.toString().contains('403')) {
          message = '❌ Нет прав. Проверьте RLS политики в Supabase.';
        }
        ErrorHandler.showErrorSnackBar(context, e, customMessage: message);
      }
    }
  }

  Future<void> _rejectReview(int reviewId, {int retryCount = 0}) async {
    try {
      await Supabase.instance.client
          .from('reviews')
          .update({'status_id': ReviewStatus.rejected})
          .eq('review_id', reviewId)
          .timeout(const Duration(seconds: 30));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отзыв отклонён'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadReviews();
      }
    } on SocketException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._rejectReview (Socket)', e);
      if (retryCount < 3 && mounted) {
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _rejectReview(reviewId, retryCount: retryCount + 1);
      }
      if (mounted) _showNetworkError();
    } on TimeoutException catch (e) {
      ErrorHandler.logError('AdminProfileScreen._rejectReview (Timeout)', e);
      if (retryCount < 3 && mounted) {
        await Future.delayed(Duration(seconds: retryCount + 1));
        return _rejectReview(reviewId, retryCount: retryCount + 1);
      }
      if (mounted) _showNetworkError();
    } catch (e) {
      ErrorHandler.logError('AdminProfileScreen._rejectReview', e);
      if (mounted) {
        String message = 'Ошибка: $e';
        if (e.toString().contains('permission') || e.toString().contains('403')) {
          message = '❌ Нет прав. Проверьте RLS политики в Supabase.';
        }
        ErrorHandler.showErrorSnackBar(context, e, customMessage: message);
      }
    }
  }

  void _showNetworkError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🌐 Проблема с соединением. Попробуйте снова.'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Выход', style: TextStyle(color: Colors.white)),
        content: const Text('Выйти из аккаунта?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('⚠️ Sign out error: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(showProfileIcon: false),
      body: Column(
        children: [
          // Заголовок
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF444444),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: const Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Color(0xFFD47926), size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Администрирование',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Модерация отзывов',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Фильтры
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('На модерации', ReviewStatus.pending),
                    const SizedBox(width: 8),
                    _buildFilterChip('Все', 0),
                    const SizedBox(width: 8),
                    _buildFilterChip('Опубликованные', ReviewStatus.published),
                    const SizedBox(width: 8),
                    _buildFilterChip('Отклонённые', ReviewStatus.rejected),
                  ],
                ),
              ),
            ),
          ),

          // Счётчик
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Всего: ${_reviews.length}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                if (_reviewFilter == ReviewStatus.pending && _reviews.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ReviewStatus.getColor(ReviewStatus.pending).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Требуют проверки',
                      style: TextStyle(
                        color: ReviewStatus.getColor(ReviewStatus.pending),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Список отзывов
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _reviews.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () => _loadReviews(),
                        color: const Color(0xFFD47926),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _reviews.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            final statusId = review['status_id'] as int? ?? ReviewStatus.pending;
                            
                            return _ReviewCard(
                              review: review,
                              onApprove: statusId != ReviewStatus.published
                                  ? () => _approveReview(review['review_id'])
                                  : null,
                              onReject: statusId != ReviewStatus.rejected
                                  ? () => _rejectReview(review['review_id'])
                                  : null,
                            );
                          },
                        ),
                      ),
          ),

          // ✅ КНОПКА ВЫХОДА (вернул)
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _signOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Выйти из аккаунта',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int filterValue) {
    final isSelected = _reviewFilter == filterValue;
    return GestureDetector(
      onTap: () {
        setState(() {
          _reviewFilter = filterValue;
          _loadReviews();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD47926) : const Color(0xFF555555),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    if (_reviewFilter == ReviewStatus.pending) {
      message = 'Нет отзывов на модерации';
      icon = Icons.check_circle_outline;
    } else if (_reviewFilter == ReviewStatus.published) {
      message = 'Нет опубликованных отзывов';
      icon = Icons.star_outline;
    } else if (_reviewFilter == ReviewStatus.rejected) {
      message = 'Нет отклонённых отзывов';
      icon = Icons.cancel_outlined;
    } else {
      message = 'Отзывы пока отсутствуют';
      icon = Icons.rate_review_outlined;
    }

    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: Colors.white24),
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _ReviewCard({
    required this.review,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final master = review['master'] as Map<String, dynamic>? ?? {};
    final client = review['client'] as Map<String, dynamic>? ?? {};
    final statusId = review['status_id'] as int? ?? ReviewStatus.pending;
    final rating = review['rating'] as int? ?? 5;
    final comment = review['comment'] as String? ?? '';
    final createdAt = review['created_at'] as String?;
    final masterName = master['full_name'] ?? 'Мастер';
    final clientName = client['full_name'] ?? 'Клиент';
    final clientPhoto = client['photo_url'];

    final statusColor = ReviewStatus.getColor(statusId);
    final statusText = ReviewStatus.getDisplayName(statusId);
    final statusIcon = ReviewStatus.getIcon(statusId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(8),
        border: statusId == ReviewStatus.pending
            ? Border.all(color: ReviewStatus.getColor(ReviewStatus.pending).withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF555555),
                  shape: BoxShape.circle,
                ),
                child: clientPhoto != null && clientPhoto.toString().isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          clientPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          clientName.isNotEmpty ? clientName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (createdAt != null)
                      Text(
                        _formatDateFromStr(createdAt),
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              const Icon(Icons.person_outline, color: Colors.white54, size: 14),
              const SizedBox(width: 4),
              Text(
                masterName,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < rating ? Icons.star : Icons.star_border,
                color: const Color(0xFFD4AF37),
                size: 16,
              );
            }),
          ),
          
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
          
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onReject != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, size: 16),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      label: const Text('Отклонить', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                if (onApprove != null && onReject != null)
                  const SizedBox(width: 8),
                if (onApprove != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onApprove,
                      icon: Icon(
                        statusId == ReviewStatus.rejected ? Icons.refresh : Icons.check,
                        size: 16,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      label: Text(
                        statusId == ReviewStatus.rejected ? 'Опубликовать' : 'Одобрить',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateFromStr(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}