/// Конфигурация для работы с Yandex Cloud Object Storage
class YandexStorageConfig {
  // 🔑 Ваши ключи доступа
  static const String accessKeyId = 'YCAJEH4EuVBuL4Jrwp66F07_a';
  static const String secretAccessKey = 'YCP7FxmKS_RweWHEyQjT_gn67q2fU3i1A2JtZiDw';
  
  // 📦 Информация о бакете
  static const String bucketName = 'tribe-portfolio';
  static const String region = 'ru-central1';
  static const String host = 'storage.yandexcloud.net';
  static const String endpoint = 'https://storage.yandexcloud.net';
  
  /// Получить публичный URL для файла
  static String getPublicUrl(String fileName) {
    return '$endpoint/$bucketName/$fileName';
  }
}