import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/error_handler.dart';
import '../utils/yandex_storage_service.dart';
import 'master/add_work_photo_screen.dart';

class MasterWorksScreen extends StatefulWidget {
  final String masterId;
  final String masterName;
  final bool canEdit;
  final bool showAppBar;

  const MasterWorksScreen({
    super.key,
    required this.masterId,
    required this.masterName,
    this.canEdit = false,
    this.showAppBar = true,
  });

  @override
  State<MasterWorksScreen> createState() => _MasterWorksScreenState();
}

class _MasterWorksScreenState extends State<MasterWorksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _portfolio = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final portfolioRes = await Supabase.instance.client
          .from('portfolio')
          .select('work_id, image_url, description, created_at')
          .eq('master_id', widget.masterId)
          .order('created_at', ascending: false)
          .range(0, 49);

      final reviewsRes = await Supabase.instance.client
          .from('reviews')
          .select('''
            review_id,
            rating,
            comment,
            created_at,
            users!reviews_client_id_fkey (full_name, photo_url)
          ''')
          .eq('master_id', widget.masterId)
          .order('created_at', ascending: false)
          .range(0, 49);

      if (mounted) {
        setState(() {
          _portfolio = List<Map<String, dynamic>>.from(portfolioRes);
          _reviews = List<Map<String, dynamic>>.from(reviewsRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('MasterWorksScreen._loadData', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _deletePhoto(int workId, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Удалить фото?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Вы уверены, что хотите удалить это фото?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      // Извлекаем имя файла из URL Yandex Cloud
      final fileName = imageUrl.split('/').last;
      
      debugPrint('🗑️ Deleting from Yandex Cloud: $fileName');
      
      // Удаляем из Yandex Cloud
      await YandexStorageService().deleteFile(fileName);

      // Удаляем запись из Supabase
      await Supabase.instance.client
          .from('portfolio')
          .delete()
          .eq('work_id', workId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Фото удалено'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      ErrorHandler.logError('MasterWorksScreen._deletePhoto', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  String _formatDate(String dateStr) {
    final dt = DateTime.parse(dateStr);
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: const Color(0xFF363636),
              title: Text(widget.masterName, style: const TextStyle(color: Colors.white)),
              centerTitle: true,
            )
          : null,
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            indicatorColor: const Color(0xFFD47926),
            indicatorWeight: 2,
            tabs: const [Tab(text: 'Работы'), Tab(text: 'Отзывы')],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPortfolioTab(),
                      _buildReviewsTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: widget.canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddWorkPhotoScreen()),
                );
                if (result == true && mounted) {
                  _loadData();
                }
              },
              backgroundColor: const Color(0xFFD47926),
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text(
                'Добавить',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildPortfolioTab() {
    if (_portfolio.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Пока нет примеров работ',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Добавьте первые работы',
              style: TextStyle(color: Colors.white38, fontSize: 14),
            ),
            if (widget.canEdit) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddWorkPhotoScreen()),
                  );
                  if (result == true && mounted) {
                    _loadData();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Добавить фото'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD47926),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFD47926),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _portfolio.length,
        itemBuilder: (context, index) {
          final work = _portfolio[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: work['image_url'],
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF444444),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF444444),
                    child: const Icon(Icons.broken_image, color: Colors.white38),
                  ),
                ),
              ),
              if (work['description'] != null &&
                  work['description'].toString().isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    work['description'],
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (widget.canEdit)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _deletePhoto(work['work_id'], work['image_url']),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rate_review_outlined, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text(
              'Пока нет отзывов',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        final client = review['users!reviews_client_id_fkey']
            as Map<String, dynamic>? ??
            {};
        final rating = (review['rating'] as num?)?.toInt() ?? 0;
        final comment = review['comment'] as String?;
        final date = _formatDate(review['created_at']);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF444444),
            borderRadius: BorderRadius.circular(8),
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
                    child: client['photo_url'] != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: client['photo_url'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF555555),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Text(
                                  (client['full_name'] as String? ?? '?')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              (client['full_name'] as String? ?? '?')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client['full_name'] ?? 'Клиент',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          date,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: List.generate(
                      5,
                      (i) => Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFD4AF37),
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  comment,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}