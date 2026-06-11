import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';
import '../../utils/cache_service.dart';
import 'edit_master_profile_screen.dart';

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
  bool _hasError = false;
  String _errorMessage = '';
  String _activeTab = 'upcoming';

  final CacheService _cache = CacheService();

  static const _months = [
    'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    // 🔥 Сначала показываем кеш
    if (!forceRefresh) {
      final cachedAppointments = await _cache.getFromStorage<List>(
        'master_appointments_${_activeTab}_${widget.masterId}',
      );

      if (cachedAppointments != null) {
        debugPrint('✅ Master appointments loaded from cache ($_activeTab)');
        if (mounted) {
          setState(() {
            _appointments = List<Map<String, dynamic>>.from(cachedAppointments);
            _isLoading = false;
          });
        }
      }

      final cachedMaster = await _cache.getFromStorage<Map>('master_${widget.masterId}');
      if (cachedMaster != null && _master == null) {
        setState(() {
          _master = Map<String, dynamic>.from(cachedMaster);
        });
      }
    }

    // Если уже есть данные из кеша, не показываем индикатор загрузки
    if (_appointments.isNotEmpty || _master != null) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // Загружаем данные мастера
      final masterResponse = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, master_rank, is_active')
          .eq('user_id', widget.masterId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      if (masterResponse != null) {
        await _cache.set('master_${widget.masterId}', masterResponse,
            duration: const Duration(minutes: 30));
      }

      // ✅ Правильная фильтрация по дате
      final now = DateTime.now().toIso8601String();

      List<dynamic> appointmentsResponse;

      if (_activeTab == 'upcoming') {
        appointmentsResponse = await Supabase.instance.client
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
            .eq('status', 'забронировано')
            .gte('start_datetime', now)
            .order('start_datetime', ascending: true)
            .timeout(const Duration(seconds: 10));
      } else {
        appointmentsResponse = await Supabase.instance.client
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
            .or('status.eq.завершено,status.eq.отменено,start_datetime.lt.$now')
            .order('start_datetime', ascending: false)
            .timeout(const Duration(seconds: 10));
      }

      final appointmentsList = List<Map<String, dynamic>>.from(appointmentsResponse);
      await _cache.set(
        'master_appointments_${_activeTab}_${widget.masterId}',
        appointmentsList,
        duration: const Duration(minutes: 2),
      );

      if (!mounted) return;

      setState(() {
        _master = masterResponse;
        _appointments = appointmentsList;
        _isLoading = false;
        _hasError = false;
      });
    } on SocketException catch (e) {
      // ✅ Исправлено: только SocketException (включает HttpException)
      ErrorHandler.logError('MasterProfileScreen._loadProfile (Network)', e);
      _handleNetworkError('Нет подключения к интернету. Проверьте соединение.');
    } catch (e) {
      // ✅ Исправлено: общий catch для всех остальных ошибок
      ErrorHandler.logError('MasterProfileScreen._loadProfile', e);
      
      // Fallback на кеш
      if (_appointments.isEmpty) {
        final cachedAppointments = await _cache.getFromStorage<List>(
          'master_appointments_${_activeTab}_${widget.masterId}',
        );
        if (cachedAppointments != null && mounted) {
          setState(() {
            _appointments = List<Map<String, dynamic>>.from(cachedAppointments);
            _isLoading = false;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = ErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  void _handleNetworkError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = message;
      });

      // Показываем кеш если есть
      if (_appointments.isEmpty) {
        _cache.getFromStorage<List>('master_appointments_${_activeTab}_${widget.masterId}').then((cached) {
          if (cached != null && mounted) {
            setState(() {
              _appointments = List<Map<String, dynamic>>.from(cached);
              _hasError = false; // Не показываем ошибку если есть кеш
            });
          }
        });
      }
    }
  }

  Future<void> _refreshProfile() async {
    await _loadProfile(forceRefresh: true);
  }

  Future<void> _openEditProfile() async {
    if (_master == null) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditMasterProfileScreen(
          currentMaster: _master!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _cache.clear('master_${widget.masterId}');
      _loadProfile(forceRefresh: true);
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Запись отменена'), backgroundColor: Colors.green),
        );

        await _cache.clear('master_appointments_upcoming_${widget.masterId}');
        await _cache.clear('master_appointments_past_${widget.masterId}');

        _loadProfile(forceRefresh: true);
      }
    } catch (e) {
      ErrorHandler.logError('MasterProfileScreen._cancelAppointment', e);
      if (mounted) ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Выход', style: TextStyle(color: Colors.white)),
        content: const Text('Вы уверены, что хотите выйти из аккаунта?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Выйти', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _cache.clear();
      await Supabase.instance.client.auth.signOut();
    } on AuthRetryableFetchException {
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
      appBar: const TribeAppBar(showProfileIcon: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _hasError && _appointments.isEmpty
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _refreshProfile,
                  color: const Color(0xFFD47926),
                  child: Column(
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
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white54),
                              onPressed: _openEditProfile,
                              tooltip: 'Редактировать профиль',
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
                                  onTap: () {
                                    if (!mounted) return;
                                    setState(() {
                                      _activeTab = 'upcoming';
                                      _loadProfile();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(color: _activeTab == 'upcoming' ? const Color(0xFFD47926) : Colors.transparent, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))),
                                    child: Center(child: Text('Активные', style: TextStyle(color: _activeTab == 'upcoming' ? Colors.white : Colors.white54, fontSize: 14, fontWeight: FontWeight.w500))),
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
                            ? ListView(
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.4,
                                    child: Center(
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
                                    ),
                                  ),
                                ],
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

                                  return _AppointmentCard(
                                    appointmentId: appt['appointment_id'],
                                    serviceName: service['name'] ?? 'Услуга',
                                    clientName: client['full_name'] ?? 'Клиент',
                                    clientPhone: client['phone'],
                                    dateTime: _formatDateTime(appt['start_datetime']),
                                    duration: _calculateDuration(appt['start_datetime'], appt['end_datetime']),
                                    status: status,
                                    canCancel: _activeTab == 'upcoming' && status == 'забронировано',
                                    onCancel: () => _cancelAppointment(appt['appointment_id']),
                                  );
                                },
                              ),
                      ),

                      // КНОПКА ВЫХОДА
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
                ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Не удалось загрузить данные',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Попробовать снова'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD47926),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
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