import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String _activeTab = 'upcoming';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final userResponse = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url')
          .eq('user_id', userId)
          .single();

      final appointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('''
            appointment_id,
            start_datetime,
            end_datetime,
            status,
            services (name),
            users!appointments_barber_id_fkey (full_name)
          ''')
          .eq('polzovatel_id', userId)
          .order('start_datetime', ascending: _activeTab == 'upcoming');

      if (!mounted) return;
      setState(() {
        _user = userResponse;
        _appointments = List<Map<String, dynamic>>.from(appointmentsResponse);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _cancelAppointment(int appointmentId) async {
    try {
      await Supabase.instance.client
          .from('appointments')
          .update({'status': 'отменено'})
          .eq('appointment_id', appointmentId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Запись отменена'),
          backgroundColor: Colors.green,
        ),
      );
      _loadProfile();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка отмены: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    final weekday = weekdays[dt.weekday - 1];
    return '$weekday, ${dt.day} мая, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  // ✅ Статический метод для получения цвета статуса
  static Color _getStatusColor(String status) {
    switch (status) {
      case 'забронировано':
        return const Color(0xFF4CAF50);
      case 'отменено':
        return const Color(0xFFF44336);
      case 'завершено':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                // 👤 Профиль пользователя
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF444444),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF555555),
                          shape: BoxShape.circle,
                        ),
                        child: _user?['photo_url'] != null && _user!['photo_url'].toString().isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _user!['photo_url'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 32),
                                ),
                              )
                            : const Icon(Icons.person, color: Colors.white54, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _user?['full_name'] ?? 'Пользователь',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _user?['email'] ?? '',
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
                            ),
                            if (_user?['phone'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _user!['phone'],
                                style: const TextStyle(color: Colors.white54, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white54),
                        onPressed: () {
                          // TODO: экран редактирования профиля
                        },
                      ),
                    ],
                  ),
                ),

                // 📋 Табы
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF444444),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                _activeTab = 'upcoming';
                                _loadProfile();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _activeTab == 'upcoming'
                                    ? const Color(0xFFD47926)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(8),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Активные',
                                  style: TextStyle(
                                    color: _activeTab == 'upcoming'
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (!mounted) return;
                              setState(() {
                                _activeTab = 'past';
                                _loadProfile();
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _activeTab == 'past'
                                    ? const Color(0xFFD47926)
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(8),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Прошедшие',
                                  style: TextStyle(
                                    color: _activeTab == 'past'
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 📅 Список записей
                Expanded(
                  child: _appointments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _activeTab == 'upcoming' ? Icons.event_busy : Icons.history,
                                size: 64,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _activeTab == 'upcoming'
                                    ? 'Нет активных записей'
                                    : 'Нет прошедших записей',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 16,
                                ),
                              ),
                              if (_activeTab == 'upcoming') ...[
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    if (!context.mounted) return;
                                    Navigator.pushNamed(context, '/services');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD47926),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text('Записаться'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _appointments.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final appt = _appointments[index];
                            final service = appt['services'] as Map<String, dynamic>? ?? {};
                            final barber = appt['users!appointments_barber_id_fkey'] as Map<String, dynamic>? ?? {};
                            
                            return _AppointmentCard(
                              appointmentId: appt['appointment_id'],
                              serviceName: service['name'] ?? 'Услуга',
                              masterName: barber['full_name'] ?? 'Мастер',
                              dateTime: _formatDateTime(appt['start_datetime']),
                              duration: _calculateDuration(
                                appt['start_datetime'],
                                appt['end_datetime'],
                              ),
                              status: appt['status'],
                              onCancel: _activeTab == 'upcoming'
                                  ? () => _cancelAppointment(appt['appointment_id'])
                                  : null,
                            );
                          },
                        ),
                ),

                // 🔘 Кнопка выхода
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (!mounted) return;
                        if (!context.mounted) return;
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          '/login',
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _calculateDuration(String startStr, String endStr) {
    try {
      final start = DateTime.parse(startStr);
      final end = DateTime.parse(endStr);
      final minutes = end.difference(start).inMinutes;
      return '$minutes мин';
    } catch (_) {
      return '~ 60 мин';
    }
  }
}

// 🎫 Карточка записи
class _AppointmentCard extends StatelessWidget {
  final int appointmentId;
  final String serviceName;
  final String masterName;
  final String dateTime;
  final String duration;
  final String status;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointmentId,
    required this.serviceName,
    required this.masterName,
    required this.dateTime,
    required this.duration,
    required this.status,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == 'отменено';
    final isCompleted = status == 'завершено';

    // ✅ Используем статический метод из родительского класса
    final statusColor = _ProfileScreenState._getStatusColor(status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCancelled || isCompleted
            ? const Color(0xFF3A3A3A)
            : const Color(0xFF444444),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isCancelled
              ? Colors.red.withValues(alpha: 0.3) // ✅ Исправлено: withValues вместо withOpacity
              : isCompleted
                  ? Colors.white24
                  : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  serviceName,
                  style: TextStyle(
                    color: isCancelled || isCompleted
                        ? Colors.white38
                        : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status == 'забронировано'
                      ? 'Активно'
                      : status == 'отменено'
                          ? 'Отменено'
                          : 'Завершено',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.person, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                masterName,
                style: TextStyle(
                  color: isCancelled || isCompleted
                      ? Colors.white38
                      : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                dateTime,
                style: TextStyle(
                  color: isCancelled || isCompleted
                      ? Colors.white38
                      : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white54, size: 16),
              const SizedBox(width: 6),
              Text(
                duration,
                style: TextStyle(
                  color: isCancelled || isCompleted
                      ? Colors.white38
                      : Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (onCancel != null && !isCancelled && !isCompleted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  'Отменить запись',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}