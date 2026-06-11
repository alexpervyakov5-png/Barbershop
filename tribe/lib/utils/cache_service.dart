import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final Map<String, _CacheEntry> _memoryCache = {};
  static const Duration _defaultCacheDuration = Duration(minutes: 5);

  // 🔥 Кеширование в памяти + localStorage
  Future<void> set<T>(String key, T value, {Duration? duration}) async {
    final expiry = DateTime.now().add(duration ?? _defaultCacheDuration);
    _memoryCache[key] = _CacheEntry(value: value, expiry: expiry);
    
    // Сохраняем в localStorage для сложных объектов
    if (value is Map || value is List) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${key}_data', jsonEncode(value));
      await prefs.setInt('${key}_expiry', expiry.millisecondsSinceEpoch);
    }
  }

  T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.value as T;
  }

  // 🔥 Кеширование из localStorage
  Future<T?> getFromStorage<T>(String key) async {
    // Сначала пробуем память
    final memoryValue = get<T>(key);
    if (memoryValue != null) return memoryValue;

    // Потом localStorage
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('${key}_data');
    final expiry = prefs.getInt('${key}_expiry');
    
    if (data == null || expiry == null) return null;
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      await clear(key);
      return null;
    }

    final decoded = jsonDecode(data) as T;
    // Восстанавливаем в памяти
    set(key, decoded);
    return decoded;
  }

  Future<void> clear([String? key]) async {
    if (key != null) {
      _memoryCache.remove(key);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${key}_data');
      await prefs.remove('${key}_expiry');
    } else {
      _memoryCache.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  bool isValid(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return false;
    return DateTime.now().isBefore(entry.expiry);
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiry;
  _CacheEntry({required this.value, required this.expiry});
}