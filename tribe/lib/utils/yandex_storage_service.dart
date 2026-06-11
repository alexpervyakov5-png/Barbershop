import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'yandex_storage_config.dart';

class YandexStorageService {
  static final YandexStorageService _instance = YandexStorageService._internal();
  factory YandexStorageService() => _instance;
  YandexStorageService._internal();

  final http.Client _client = http.Client();

  Future<String> uploadFile({
    required File file,
    required String fileName,
  }) async {
    try {
      debugPrint('📤 Uploading file: $fileName');
      
      final bytes = await file.readAsBytes();
      final uri = Uri.parse('${YandexStorageConfig.endpoint}/${YandexStorageConfig.bucketName}/$fileName');
      
      // Простой запрос без подписи (должен работать если bucket public write)
      final response = await _client.put(
        uri,
        headers: {
          'Content-Type': 'image/jpeg',
          'x-amz-acl': 'public-read',
        },
        body: bytes,
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = YandexStorageConfig.getPublicUrl(fileName);
        debugPrint('✅ File uploaded: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('❌ Upload failed: ${response.statusCode}\n${response.body}');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      rethrow;
    }
  }

  Future<void> deleteFile(String fileName) async {
    try {
      debugPrint('🗑️ Deleting file: $fileName');
      
      final uri = Uri.parse('${YandexStorageConfig.endpoint}/${YandexStorageConfig.bucketName}/$fileName');
      
      final response = await _client.delete(uri);
      
      if (response.statusCode == 204 || response.statusCode == 200) {
        debugPrint('✅ File deleted');
      } else {
        throw Exception('Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      rethrow;
    }
  }
}