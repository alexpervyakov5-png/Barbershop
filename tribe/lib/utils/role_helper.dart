import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  client(1),
  master(2),
  admin(3);

  final int id;
  const UserRole(this.id);

  static UserRole? fromId(int? id) {
    switch (id) {
      case 1: return UserRole.client;
      case 2: return UserRole.master;
      case 3: return UserRole.admin;
      default: return null;
    }
  }
}

class RoleHelper {
  // ✅ ИСПРАВЛЕНО: Кэширование роли пользователя
  static UserRole? _cachedRole;
  static DateTime? _cacheTimestamp;

  /// Получить роль текущего пользователя с кэшированием (кэш живет 5 минут)
  static Future<UserRole?> getCurrentRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final now = DateTime.now();
    if (_cachedRole != null && 
        _cacheTimestamp != null && 
        now.difference(_cacheTimestamp!).inMinutes < 5) {
      return _cachedRole;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role_id')
          .eq('user_id', user.id)
          .single();

      final roleId = response['role_id'] as int?;
      _cachedRole = UserRole.fromId(roleId);
      _cacheTimestamp = now;
      
      return _cachedRole;
    } catch (e) {
      return null;
    }
  }

  /// Проверка: текущий пользователь — админ?
  static Future<bool> get isAdmin async {
    final role = await getCurrentRole();
    return role == UserRole.admin;
  }

  /// Проверка прав для конкретного экрана
  static Future<bool> requireAdmin() async {
    return await isAdmin;
  }
  
  /// Сброс кэша (например, при выходе из аккаунта)
  static void clearCache() {
    _cachedRole = null;
    _cacheTimestamp = null;
  }
}