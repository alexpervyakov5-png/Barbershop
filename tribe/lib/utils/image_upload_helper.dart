import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Выбор изображения из галереи или камеры
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
    } catch (e) {
      debugPrint('❌ Ошибка выбора изображения: $e');
    }
    return null;
  }

  /// Загрузка фото в портфолио мастера
  static Future<String?> uploadPortfolioImage({
    required String masterId,
    required File imageFile,
    String? description,
  }) async {
    try {
      final fileName = '${masterId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final storage = Supabase.instance.client.storage.from('portfolio');
      
      await storage.uploadBinary(
        fileName,
        await imageFile.readAsBytes(),
        fileOptions: const FileOptions(
          contentType: 'image/jpeg',
          upsert: false,
        ),
      );

      final publicUrl = storage.getPublicUrl(fileName);

      await Supabase.instance.client.from('portfolio').insert({
        'master_id': masterId,
        'image_url': publicUrl,
        'description': description,
      });

      debugPrint('✅ Фото загружено: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки фото: $e');
      return null;
    }
  }

  /// Удаление фото из портфолио
  static Future<bool> deletePortfolioImage({
    required String imageUrl,
    required int workId,
  }) async {
    try {
      final fileName = imageUrl.split('/').last;
      
      await Supabase.instance.client.storage
          .from('portfolio')
          .remove([fileName]);

      await Supabase.instance.client
          .from('portfolio')
          .delete()
          .eq('work_id', workId);

      debugPrint('✅ Фото удалено');
      return true;
    } catch (e) {
      debugPrint('❌ Ошибка удаления фото: $e');
      return false;
    }
  }

  /// Показ диалога выбора источника фото
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF444444),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Сделать фото', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Выбрать из галереи', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      return pickImage(source);
    }
    return null;
  }
}