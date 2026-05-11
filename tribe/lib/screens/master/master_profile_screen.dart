import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

class MasterProfileScreen extends StatefulWidget {
  final String masterId;
  final String masterName;

  const MasterProfileScreen({
    super.key,
    required this.masterId,
    required this.masterName,
  });

  @override
  State<MasterProfileScreen> createState() => _MasterProfileScreenState();
}

class _MasterProfileScreenState extends State<MasterProfileScreen> {
  Map<String, dynamic>? _master;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String _activeTab = 'upcoming';

  static const _months = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final masterResponse = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, master_rank, is_active')
          .eq('user_id', widget.masterId)
          .maybeSingle();

      final appointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('''
            appointment_id,
            start_datetime,
            end_datetime,
            status,
            services (service_id, name),
            users!appointments_client_id_fkey (user_id, full_name, phone)
          ''')
          .eq('barber_id', widget.masterId)
          .order('start_datetime', ascending: _activeTab == 'upcoming');

      if (!mounted) return;
      
      setState(() {
        _master = masterResponse;
        _appointments = List<Map<String, dynamic>>.from(appointmentsResponse);
        _isLoading = false;
      });
    } catch (e) {
      ErrorHandler.logError('MasterProfileScreen._loadProfile', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  String _formatDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    const weekdays = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
    final weekday = weekdays[dt.weekday - 1];
    final month = _months[dt.month - 1];
    return '$weekday, ${dt.day} $month, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _cancelAppointment(int appointmentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Отменить запись?', style: TextStyle(color: Colors.white)),
        content: const Text('Вы уверены, что хотите отменить эту запись?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Нет', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Да, отменить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('appointments')
          .update({'status': 'отменено'})
          .eq('appointment_id', appointmentId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Запись отменена'), backgroundColor: Colors.green));
        _loadProfile();
      }
    } catch (e) {
      ErrorHandler.logError('MasterProfileScreen._cancelAppointment', e);
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  /// ✅ Логика выхода из аккаунта
  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthRetryableFetchException {
      // Сетевая ошибка: принудительно очищаем локальную сессию
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('❌ Ошибка при выходе: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
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
                // 👤 Профиль мастера
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
                        decoration: const BoxDecoration(color: Color(0xFF555555), shape: BoxShape.circle),
                        child: _master?['photo_url'] != null && _master!['photo_url'].toString().isNotEmpty
                            ? ClipOval(child: Image.network(_master!['photo_url'], fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 32)))
                            : const Icon(Icons.person, color: Colors.white54, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_master?['full_name'] ?? widget.masterName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            if (_master?['master_rank'] != null) Text(_master!['master_rank'], style: const TextStyle(color: Color(0xFFD47926), fontSize: 14, fontWeight: FontWeight.w500)),
                            if (_master?['email'] != null) ...[const SizedBox(height: 4), Text(_master!['email'], style: const TextStyle(color: Colors.white54, fontSize: 13))],
                            if (_master?['phone'] != null) ...[const SizedBox(height: 2), Text(_master!['phone'], style: const TextStyle(color: Colors.white54, fontSize: 13))],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: (_master?['is_active'] == true) ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          (_master?['is_active'] == true) ? 'Активен' : 'Не активен',
                          style: TextStyle(color: (_master?['is_active'] == true) ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

                // 📋 Табы
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { if (!mounted) return; setState(() { _activeTab = 'upcoming'; _loadProfile(); }); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: _activeTab == 'upcoming' ? const Color(0xFFD47926) : Colors.transparent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))),
                              child: Center(child: Text('Активные', style: TextStyle(color: _activeTab == 'upcoming' ? Colors.white : Colors.white54, fontSize: 14, fontWeight: FontWeight.w500))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () { if (!mounted) return; setState(() { _activeTab = 'past'; _loadProfile(); }); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: _activeTab == 'past' ? const Color(0xFFD47926) : Colors.transparent, borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))),
                              child: Center(child: Text('Прошедшие', style: TextStyle(color: _activeTab == 'past' ? Colors.white : Colors.white54, fontSize: 14, fontWeight: FontWeight.w500))),
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
                              Icon(_activeTab == 'upcoming' ? Icons.event_busy : Icons.history, size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              Text(_activeTab == 'upcoming' ? 'Нет активных записей' : 'Нет прошедших записей', style: const TextStyle(color: Colors.white54, fontSize: 16)),
                              const SizedBox(height: 8),
                              Text(_activeTab == 'upcoming' ? 'Клиенты пока не записались' : 'История записей пуста', style: const TextStyle(color: Colors.white38, fontSize: 13)),
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
                            final client = appt['users!appointments_client_id_fkey'] as Map<String, dynamic>? ?? {};
                            final status = appt['status'] as String? ?? 'забронировано';
                            final isPast = _activeTab == 'past' || status == 'завершено' || status == 'отменено';
                            
                            return _AppointmentCard(
                              appointmentId: appt['appointment_id'],
                              serviceName: service['name'] ?? 'Услуга',
                              clientName: client['full_name'] ?? 'Клиент',
                              clientPhone: client['phone'],
                              dateTime: _formatDateTime(appt['start_datetime']),
                              duration: _calculateDuration(appt['start_datetime'], appt['end_datetime']),
                              status: status,
                              canCancel: !isPast && status == 'забронировано',
                              onCancel: () => _cancelAppointment(appt['appointment_id']),
                            );
                          },
                        ),
                ),

                // ✅ КНОПКА ВЫХОДА (добавлена)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: _signOut,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('Выйти из аккаунта', style: TextStyle(fontSize: 16)),
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
      return '${end.difference(start).inMinutes} мин';
    } catch (_) {
      return '~ 60 мин';
    }
  }
}

// 🎫 Карточка записи (без изменений)
class _AppointmentCard extends StatelessWidget {
  final int appointmentId;
  final String serviceName;
  final String clientName;
  final String? clientPhone;
  final String dateTime;
  final String duration;
  final String status;
  final bool canCancel;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointmentId,
    required this.serviceName,
    required this.clientName,
    this.clientPhone,
    required this.dateTime,
    required this.duration,
    required this.status,
    required this.canCancel,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == 'отменено';
    final isCompleted = status == 'завершено';
    final statusColor = status == 'забронировано' ? const Color(0xFF4CAF50) : status == 'отменено' ? const Color(0xFFF44336) : const Color(0xFF9E9E9E);
    final statusText = status == 'забронировано' ? 'Активно' : status == 'отменено' ? 'Отменено' : 'Завершено';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCancelled || isCompleted ? const Color(0xFF3A3A3A) : const Color(0xFF444444),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isCancelled ? Colors.red.withValues(alpha: 0.3) : isCompleted ? Colors.white.withValues(alpha: 0.2) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(serviceName, style: TextStyle(color: isCancelled || isCompleted ? Colors.white.withValues(alpha: 0.3) : Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.person, color: Colors.white54, size: 16), const SizedBox(width: 6), Text(clientName, style: TextStyle(color: isCancelled || isCompleted ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.7), fontSize: 14)), if (clientPhone != null && clientPhone!.isNotEmpty) ...[const SizedBox(width: 8), Text(clientPhone!, style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13))]]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.calendar_today, color: Colors.white54, size: 16), const SizedBox(width: 6), Text(dateTime, style: TextStyle(color: isCancelled || isCompleted ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.7), fontSize: 14))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.timer, color: Colors.white54, size: 16), const SizedBox(width: 6), Text(duration, style: TextStyle(color: isCancelled || isCompleted ? Colors.white.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.7), fontSize: 14))]),
          if (canCancel && onCancel != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: OutlinedButton(onPressed: onCancel, style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))), child: const Text('Отменить запись', style: TextStyle(fontSize: 14)))),
          ],
        ],
      ),
    );
  }
}