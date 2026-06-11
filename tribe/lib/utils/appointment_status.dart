import 'package:flutter/material.dart';

/// Константы статусов записей (3НФ)
class AppointmentStatus {
  static const int booked = 1;      // забронировано
  static const int completed = 2;   // завершено
  static const int cancelled = 3;   // отменено
  static const int rescheduled = 4; // перенесено
  
  static String getName(int statusId) {
    switch (statusId) {
      case booked: return 'забронировано';
      case completed: return 'завершено';
      case cancelled: return 'отменено';
      case rescheduled: return 'перенесено';
      default: return 'неизвестно';
    }
  }
  
  static String getDisplayName(int statusId) {
    switch (statusId) {
      case booked: return 'Активно';
      case completed: return 'Завершено';
      case cancelled: return 'Отменено';
      case rescheduled: return 'Перенесено';
      default: return 'Неизвестно';
    }
  }
  
  static Color getColor(int statusId) {
    switch (statusId) {
      case booked: return const Color(0xFF4CAF50);
      case completed: return const Color(0xFF9E9E9E);
      case cancelled: return const Color(0xFFF44336);
      case rescheduled: return const Color(0xFFFF9800);
      default: return Colors.white;
    }
  }
}