import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole {
  client(1),
  master(2),
  admin(3);

  final int id;
  const UserRole(this.id);

  static UserRole? fromId(int? id) {
    switch (id) {
      case 1:
        return UserRole.client;
      case 2:
        return UserRole.master;
      case 3:
        return UserRole.admin;
      default:
        return null;
    }
  }
}

class RoleHelper {
  /// Проверка: текущий пользователь — админ?
  static Future<bool> get isAdmin async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role_id')
          .eq('user_id', user.id)
          .single();

      final roleId = response['role_id'] as int?;
      return roleId == UserRole.admin.id;
    } catch (e) {
      return false;
    }
  }

  /// Получить роль текущего пользователя
  static Future<UserRole?> getCurrentRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('role_id')
          .eq('user_id', user.id)
          .single();

      return UserRole.fromId(response['role_id'] as int?);
    } catch (e) {
      return null;
    }
  }

  /// Проверка прав для конкретного экрана
  static Future<bool> requireAdmin() async {
    final role = await getCurrentRole();
    return role == UserRole.admin;
  }
}