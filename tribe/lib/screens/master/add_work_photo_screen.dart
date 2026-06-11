import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import '../../utils/error_handler.dart';

class AddWorkPhotoScreen extends StatefulWidget {
  const AddWorkPhotoScreen({super.key});

  @override
  State<AddWorkPhotoScreen> createState() => _AddWorkPhotoScreenState();
}

class _AddWorkPhotoScreenState extends State<AddWorkPhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUploading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final originalFile = File(pickedFile.path);
        final originalSize = await originalFile.length();
        debugPrint('📦 Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        final compressed = await _compressImage(originalFile);
        final compressedSize = await compressed.length();
        debugPrint('📦 Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        setState(() {
          _selectedImage = compressed;
        });
      }
    } catch (e) {
      ErrorHandler.logError('AddWorkPhotoScreen._pickImage', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось выбрать изображение',
        );
      }
    }
  }

  Future<File> _compressImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      
      if (bytes.length < 2 * 1024 * 1024) return file;

      final image = img.decodeImage(bytes);
      if (image == null) return file;

      final compressed = img.copyResize(
        image,
        width: 1200,
        interpolation: img.Interpolation.linear,
      );

      final compressedBytes = img.encodeJpg(compressed, quality: 80);
      final compressedFile = File('${file.path}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      debugPrint('📦 Compressed: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB → ${(compressedBytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
      return compressedFile;
    } catch (e) {
      debugPrint('⚠️ Compression failed: $e');
      return file;
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF363636),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
              title: const Text('Сделать фото', style: TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white, size: 28),
              title: const Text('Выбрать из галереи', style: TextStyle(color: Colors.white, fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ✅ ИСПРАВЛЕНО: Убран параметр limit
  Future<bool> _fileExistsInStorage(String fileName) async {
    try {
      final storage = Supabase.instance.client.storage.from('portfolio');
      final files = await storage.list();
      return files.any((file) => file.name == fileName);
    } catch (e) {
      debugPrint('⚠️ Failed to check file existence: $e');
      return false;
    }
  }

  Future<void> _uploadPhoto() async {
    if (_selectedImage == null || _userId == null) return;

    setState(() => _isUploading = true);

    final fileName = '${_userId!}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final storage = Supabase.instance.client.storage.from('portfolio');

    const int maxRetries = 3;
    int retryCount = 0;
    bool storageUploaded = false;
    String? publicUrl;

    while (retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          debugPrint('🔄 Retry attempt ${retryCount + 1}/$maxRetries');
          await Future.delayed(Duration(seconds: retryCount));
        }

        if (!storageUploaded) {
          final exists = await _fileExistsInStorage(fileName);
          if (exists) {
            debugPrint('✅ File already exists in Storage, skipping upload');
            publicUrl = storage.getPublicUrl(fileName);
            storageUploaded = true;
          }
        }

        if (!storageUploaded) {
          debugPrint('📤 Uploading to: portfolio/$fileName');
          debugPrint('📦 File size: ${(_selectedImage!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB');

          await storage.uploadBinary(
            fileName,
            await _selectedImage!.readAsBytes(),
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          ).timeout(const Duration(seconds: 60));

          publicUrl = storage.getPublicUrl(fileName);
          storageUploaded = true;
          debugPrint('✅ File uploaded to Storage: $publicUrl');
        }

        debugPrint('💾 Saving to database...');
        await Supabase.instance.client.from('portfolio').insert({
          'master_id': _userId!,
          'image_url': publicUrl,
          'description': _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
        }).timeout(const Duration(seconds: 15));

        debugPrint('✅ Saved to database');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Фото успешно добавлено'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
        return;

      } on SocketException catch (e) {
        ErrorHandler.logError('AddWorkPhotoScreen._uploadPhoto (Socket)', e);
        retryCount++;
        
        if (!storageUploaded) {
          final exists = await _fileExistsInStorage(fileName);
          if (exists) {
            debugPrint('✅ File uploaded despite SocketException');
            publicUrl = storage.getPublicUrl(fileName);
            storageUploaded = true;
            retryCount = 0;
            continue;
          }
        }
        
        if (retryCount >= maxRetries) {
          if (storageUploaded) {
            await _cleanupStorage(storage, fileName);
          }
          if (mounted) {
            setState(() => _isUploading = false);
            _showErrorDialog('Нет подключения к интернету. Проверьте соединение и попробуйте снова.');
          }
          return;
        }
      } on TimeoutException catch (e) {
        ErrorHandler.logError('AddWorkPhotoScreen._uploadPhoto (Timeout)', e);
        retryCount++;
        
        if (!storageUploaded) {
          final exists = await _fileExistsInStorage(fileName);
          if (exists) {
            debugPrint('✅ File uploaded despite TimeoutException');
            publicUrl = storage.getPublicUrl(fileName);
            storageUploaded = true;
            retryCount = 0;
            continue;
          }
        }
        
        if (retryCount >= maxRetries) {
          if (storageUploaded) {
            await _cleanupStorage(storage, fileName);
          }
          if (mounted) {
            setState(() => _isUploading = false);
            _showErrorDialog('Превышено время ожидания. Проверьте интернет и попробуйте снова.');
          }
          return;
        }
      } on StorageException catch (e) {
        ErrorHandler.logError('AddWorkPhotoScreen._uploadPhoto (Storage)', e);
        
        String message = 'Ошибка загрузки фото';
        
        if (e.message.contains('permission') || e.message.contains('403')) {
          message = 'Нет прав доступа. Проверьте настройки Supabase Storage.';
        } else if (e.message.contains('size') || e.message.contains('413')) {
          message = 'Файл слишком большой. Максимум 5MB.';
        } else if (e.message.contains('bucket')) {
          message = 'Bucket "portfolio" не найден. Создайте его в Supabase.';
        } else if (e.message.contains('Duplicate')) {
          publicUrl = storage.getPublicUrl(fileName);
          storageUploaded = true;
          debugPrint('✅ File already exists, using existing: $publicUrl');
          retryCount++;
          continue;
        }
        
        if (mounted) {
          setState(() => _isUploading = false);
          _showErrorDialog(message);
        }
        return;
      } on PostgrestException catch (e) {
        ErrorHandler.logError('AddWorkPhotoScreen._uploadPhoto (Postgrest)', e);
        
        if (storageUploaded) {
          await _cleanupStorage(storage, fileName);
        }
        
        if (mounted) {
          setState(() => _isUploading = false);
          _showErrorDialog('Ошибка базы данных: ${e.message}');
        }
        return;
      } catch (e) {
        ErrorHandler.logError('AddWorkPhotoScreen._uploadPhoto', e);
        retryCount++;
        
        if (!storageUploaded) {
          final exists = await _fileExistsInStorage(fileName);
          if (exists) {
            debugPrint('✅ File uploaded despite error');
            publicUrl = storage.getPublicUrl(fileName);
            storageUploaded = true;
            retryCount = 0;
            continue;
          }
        }
        
        if (retryCount >= maxRetries) {
          if (storageUploaded) {
            await _cleanupStorage(storage, fileName);
          }
          if (mounted) {
            setState(() => _isUploading = false);
            _showErrorDialog('Не удалось загрузить фото: $e');
          }
          return;
        }
      }
    }
  }

  Future<void> _cleanupStorage(dynamic storage, String fileName) async {
    try {
      await storage.remove([fileName]);
      debugPrint('🗑️ Cleaned up file from Storage: $fileName');
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup Storage: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Ошибка', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Добавить работу',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (_selectedImage != null)
            TextButton(
              onPressed: _isUploading ? null : _uploadPhoto,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Опубликовать',
                      style: TextStyle(
                        color: Color(0xFFD47926),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: _isUploading ? null : _showImageSourceDialog,
                    child: Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: const Color(0xFF444444),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedImage != null
                              ? const Color(0xFFD47926)
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.5),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!_isUploading)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedImage = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.6),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF555555),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate,
                                    color: Colors.white54,
                                    size: 48,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Нажмите, чтобы добавить фото',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Камера или галерея',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Описание (необязательно)',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    enabled: !_isUploading,
                    decoration: InputDecoration(
                      hintText: 'Расскажите о работе...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF444444),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.transparent),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD47926),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              color: const Color(0xFF363636),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _uploadPhoto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isUploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Загрузка...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Опубликовать работу',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}