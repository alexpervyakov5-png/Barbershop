import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/image_upload_helper.dart';
import '../../utils/error_handler.dart';

class MasterWorksScreen extends StatefulWidget {
  final String masterId;
  final String masterName;

  const MasterWorksScreen({
    super.key,
    required this.masterId,
    required this.masterName,
  });

  @override
  State<MasterWorksScreen> createState() => _MasterWorksScreenState();
}

class _MasterWorksScreenState extends State<MasterWorksScreen> {
  List<Map<String, dynamic>> _portfolio = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await Supabase.instance.client
          .from('portfolio')
          .select('work_id, image_url, description, created_at')
          .eq('master_id', widget.masterId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _portfolio = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('MasterWorksScreen._loadPortfolio', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final imageFile = await ImageUploadHelper.showImageSourceDialog(context);
    if (imageFile == null) return;

    setState(() => _isUploading = true);
    
    try {
      final publicUrl = await ImageUploadHelper.uploadPortfolioImage(
        masterId: widget.masterId,
        imageFile: imageFile,
        description: null,
      );

      if (mounted) {
        if (publicUrl != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Фото загружено'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPortfolio();
        } else {
          ErrorHandler.showErrorSnackBar(
            context,
            'Не удалось загрузить фото',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(int workId, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Удалить фото?', style: TextStyle(color: Colors.white)),
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

    if (confirm != true) return;

    final success = await ImageUploadHelper.deletePortfolioImage(
      workId: workId,
      imageUrl: imageUrl,
    );

    if (mounted && success) {
      _loadPortfolio();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _portfolio.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        const Text(
                          'Пока нет примеров работ',
                          style: TextStyle(color: Colors.white54),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _uploadPhoto,
                          icon: const Icon(Icons.add),
                          label: const Text('Добавить фото'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD47926),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
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
                            child: Image.network(
                              work['image_url'],
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: const Color(0xFF444444),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white54),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF444444),
                                child: const Icon(Icons.broken_image, color: Colors.white38),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _deletePhoto(work['work_id'], work['image_url']),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
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
        if (_isUploading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }
}