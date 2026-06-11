import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';
import '../../utils/cache_service.dart';
import '../../utils/appointment_status.dart';
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
    debugPrint('🔍 MasterProfileScreen init: masterId = ${widget.masterId}');
    _loadProfile();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;

    debugPrint('📊 Loading profile for master: ${widget.masterId}');
    debugPrint('📊 Active tab: $_activeTab');
    debugPrint('📊 Force refresh: $forceRefresh');

    setState(() {
      _hasError = false;
      _errorMessage = '';
    });

    if (!forceRefresh) {
      final cachedAppointments = await _cache.getFromStorage<List>(
        'master_appointments_${_activeTab}_${widget.masterId}',
      );

      if (cachedAppointments != null) {
        debugPrint('✅ Master appointments loaded from cache ($_activeTab): ${cachedAppointments.length} items');
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

    if (_appointments.isNotEmpty || _master != null) {
      setState(() => _isLoading = false);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      // Загружаем данные мастера
      debugPrint('👤 Loading master data...');
      final masterResponse = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, master_rank, is_active')
          .eq('user_id', widget.masterId)
          .maybeSingle()
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ Master data loaded: ${masterResponse != null ? "success" : "null"}');

      if (masterResponse != null) {
        await _cache.set('master_${widget.masterId}', masterResponse,
            duration: const Duration(minutes: 30));
      }

      final now = DateTime.now().toIso8601String();
      debugPrint('📅 Current time: $now');

      List<dynamic> appointmentsResponse;

      if (_activeTab == 'upcoming') {
        debugPrint('📋 Loading upcoming appointments...');
        // ✅ ИСПРАВЛЕНО: используем более простой запрос без алиаса
        appointmentsResponse = await Supabase.instance.client
            .from('appointments')
            .select('''
              appointment_id,
              start_datetime,
              end_datetime,
              status_id,
              barber_id,
              client_id,
              services (service_id, name),
              users!appointments_client_id_fkey (user_id, full_name, phone)
            ''')
            .eq('barber_id', widget.masterId)
            .eq('status_id', AppointmentStatus.booked)
            .gte('start_datetime', now)
            .order('start_datetime', ascending: true)
            .timeout(const Duration(seconds: 10));
      } else {
        debugPrint('📋 Loading past appointments...');
        appointmentsResponse = await Supabase.instance.client
            .from('appointments')
            .select('''
              appointment_id,
              start_datetime,
              end_datetime,
              status_id,
              barber_id,
              client_id,
              services (service_id, name),
              users!appointments_client_id_fkey (user_id, full_name, phone)
            ''')
            .eq('barber_id', widget.masterId)
            .or('status_id.eq.${AppointmentStatus.completed},status_id.eq.${AppointmentStatus.cancelled},start_datetime.lt.$now')
            .order('start_datetime', ascending: false)
            .timeout(const Duration(seconds: 10));
      }

      debugPrint('✅ Appointments loaded: ${appointmentsResponse.length} items');
      
      // ✅ Отладка: выводим первый элемент
      if (appointmentsResponse.isNotEmpty) {
        debugPrint('📋 First appointment: ${appointmentsResponse.first}');
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
      ErrorHandler.logError('MasterProfileScreen._loadProfile (Network)', e);
      _handleNetworkError('Нет подключения к интернету. Проверьте соединение.');
    } catch (e) {
      ErrorHandler.logError('MasterProfileScreen._loadProfile', e);
      debugPrint('❌ Error loading profile: $e');
      
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

      if (_appointments.isEmpty) {
        _cache.getFromStorage<List>('master_appointments_${_activeTab}_${widget.masterId}').then((cached) {
          if (cached != null && mounted) {
            setState(() {
              _appointments = List<Map<String, dynamic>>.from(cached);
              _hasError = false;
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
          .update({'status_id': AppointmentStatus.cancelled})
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

                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              _buildTab('Активные', 'upcoming'),
                              _buildTab('Прошедшие', 'past'),
                            ],
                          ),
                        ),
                      ),

                      Expanded(
                        child: _buildAppointmentsTab(),
                      ),

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

  Widget _buildTab(String label, String tabKey) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!mounted) return;
          setState(() {
            _activeTab = tabKey;
            _loadProfile();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _activeTab == tabKey ? const Color(0xFFD47926) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: _activeTab == tabKey ? Colors.white : Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return ListView(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: _appointments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final appt = _appointments[index];
        final service = appt['services'] as Map<String, dynamic>? ?? {};
        
        // ✅ ИСПРАВЛЕНО: используем 'users' вместо 'client'
        final client = appt['users!appointments_client_id_fkey'] as Map<String, dynamic>? ?? {};
        final statusId = appt['status_id'] as int? ?? AppointmentStatus.booked;

        debugPrint('👤 Client data: $client');

        return _AppointmentCard(
          appointmentId: appt['appointment_id'],
          serviceName: service['name'] ?? 'Услуга',
          clientName: client['full_name'] ?? 'Клиент',
          clientPhone: client['phone'],
          dateTime: _formatDateTime(appt['start_datetime']),
          duration: _calculateDuration(appt['start_datetime'], appt['end_datetime']),
          statusId: statusId,
          canCancel: _activeTab == 'upcoming' && statusId == AppointmentStatus.booked,
          onCancel: () => _cancelAppointment(appt['appointment_id']),
        );
      },
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
  final int statusId;
  final bool canCancel;
  final VoidCallback? onCancel;

  const _AppointmentCard({
    required this.appointmentId,
    required this.serviceName,
    required this.clientName,
    this.clientPhone,
    required this.dateTime,
    required this.duration,
    required this.statusId,
    required this.canCancel,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = statusId == AppointmentStatus.cancelled;
    final isCompleted = statusId == AppointmentStatus.completed;
    final statusColor = AppointmentStatus.getColor(statusId);
    final statusText = AppointmentStatus.getDisplayName(statusId);

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