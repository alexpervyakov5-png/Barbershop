import 'package:flutter/material.dart';

class ErrorHandler {
  /// Показывает понятное сообщение об ошибке
  static void showErrorSnackBar(BuildContext context, dynamic error, {String? customMessage}) {
    String message = getErrorMessage(error);
    
    if (customMessage != null) {
      message = customMessage;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// ✅ ПУБЛИЧНЫЙ метод для получения текста ошибки
  static String getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // Ошибки сети
    if (errorStr.contains('connection reset') || 
        errorStr.contains('socket exception') ||
        errorStr.contains('network')) {
      return '❌ Ошибка подключения к интернету. Проверьте соединение и попробуйте снова.';
    }

    if (errorStr.contains('timeout')) {
      return '⏱️ Превышено время ожидания ответа от сервера. Попробуйте позже.';
    }

    // Ошибки авторизации
    if (errorStr.contains('unauthorized') || errorStr.contains('401')) {
      return '🔐 Сессия истекла. Пожалуйста, войдите снова.';
    }

    if (errorStr.contains('forbidden') || errorStr.contains('403')) {
      return '🚫 Недостаточно прав для выполнения этого действия.';
    }

    // Ошибки Supabase
    if (errorStr.contains('supabase')) {
      return '⚠️ Ошибка сервера. Попробуйте позже.';
    }

    // Ошибки пользователя
    if (errorStr.contains('user already registered')) {
      return '👤 Пользователь с таким email уже существует.';
    }

    if (errorStr.contains('invalid email')) {
      return '📧 Некорректный email адрес.';
    }

    if (errorStr.contains('weak password')) {
      return '🔒 Пароль слишком слабый. Используйте минимум 6 символов.';
    }

    // Ошибки базы данных
    if (errorStr.contains('42501') || errorStr.contains('permission denied')) {
      return '⚠️ Недостаточно прав доступа.';
    }

    if (errorStr.contains('duplicate key')) {
      return '⚠️ Такая запись уже существует.';
    }

    // Ошибки функций
    if (errorStr.contains('function not found')) {
      return '⚠️ Функция не найдена на сервере.';
    }

    // По умолчанию
    final errorMsg = error.toString();
    return '❌ Произошла ошибка: ${errorMsg.length > 100 ? errorMsg.substring(0, 100) : errorMsg}';
  }

  /// Логирование ошибки для разработчика
  static void logError(String context, dynamic error, [StackTrace? stackTrace]) {
    debugPrint('❌ [$context] Ошибка: $error');
    if (stackTrace != null) {
      debugPrint('📋 Stack trace: $stackTrace');
    }
  }
}