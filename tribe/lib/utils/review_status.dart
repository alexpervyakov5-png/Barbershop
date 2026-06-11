import 'package:flutter/material.dart';

/// Константы статусов отзывов (3НФ)
class ReviewStatus {
  static const int pending = 1;      // на модерации
  static const int published = 2;    // опубликован
  static const int rejected = 3;     // отклонён
  static const int hidden = 4;       // скрыт
  
  static String getName(int statusId) {
    switch (statusId) {
      case pending: return 'на модерации';
      case published: return 'опубликован';
      case rejected: return 'отклонён';
      case hidden: return 'скрыт';
      default: return 'неизвестно';
    }
  }
  
  static String getDisplayName(int statusId) {
    switch (statusId) {
      case pending: return 'На модерации';
      case published: return 'Опубликован';
      case rejected: return 'Отклонён';
      case hidden: return 'Скрыт';
      default: return 'Неизвестно';
    }
  }
  
  static Color getColor(int statusId) {
    switch (statusId) {
      case pending: return const Color(0xFFFF9800);
      case published: return const Color(0xFF4CAF50);
      case rejected: return const Color(0xFFF44336);
      case hidden: return const Color(0xFF9E9E9E);
      default: return Colors.white;
    }
  }
  
  static IconData getIcon(int statusId) {
    switch (statusId) {
      case pending: return Icons.hourglass_empty;
      case published: return Icons.check_circle;
      case rejected: return Icons.cancel;
      case hidden: return Icons.visibility_off;
      default: return Icons.help;
    }
  }
}