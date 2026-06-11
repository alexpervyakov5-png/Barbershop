import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../utils/error_handler.dart';
import '../../utils/cache_service.dart';

class MasterAvailabilityScreen extends StatefulWidget {
  const MasterAvailabilityScreen({super.key});

  @override
  State<MasterAvailabilityScreen> createState() => _MasterAvailabilityScreenState();
}

class _MasterAvailabilityScreenState extends State<MasterAvailabilityScreen> {
  List<Map<String, dynamic>> _availabilityList = [];
  bool _isLoading = true;
  bool _isRetrying = false;
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);

  final CacheService _cache = CacheService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = Supabase.instance.client.auth.currentUser?.id;
    _loadAvailability();
  }

  Future<void> _loadAvailability({bool forceRefresh = false}) async {
    if (_userId == null) return;
    
    // 🔥 Сначала показываем кеш
    if (!forceRefresh) {
      final cached = await _cache.getFromStorage<List>('availability_$_userId');
      if (cached != null) {
        debugPrint('✅ Availability loaded from cache');
        if (mounted) {
          setState(() {
            _availabilityList = List<Map<String, dynamic>>.from(cached);
            _isLoading = false;
          });
        }
      }
    }

    setState(() {
      _isLoading = _availabilityList.isEmpty;
      _isRetrying = false;
    });

    try {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final thirtyDaysLater = today.add(const Duration(days: 30));

      final response = await Supabase.instance.client
          .from('availability')
          .select('date, start_time, end_time, is_available')
          .eq('barber_id', _userId!)
          .gte('date', DateFormat('yyyy-MM-dd').format(today))
          .lte('date', DateFormat('yyyy-MM-dd').format(thirtyDaysLater))
          .order('date', ascending: true)
          .timeout(const Duration(seconds: 10));

      final list = List<Map<String, dynamic>>.from(response);
      
      // 🔥 Кешируем на 5 минут
      await _cache.set('availability_$_userId', list, duration: const Duration(minutes: 5));

      if (mounted) {
        setState(() {
          _availabilityList = list;
          _isLoading = false;
        });
      }
    } on SocketException catch (e) {
      ErrorHandler.logError('MasterAvailabilityScreen._loadAvailability', e);
      if (mounted) {
        setState(() => _isLoading = false);
        _showNetworkError('Нет подключения к интернету');
      }
    } on HttpException catch (e) {
      ErrorHandler.logError('MasterAvailabilityScreen._loadAvailability', e);
      if (mounted) {
        setState(() => _isLoading = false);
        _showNetworkError('Соединение сброшено. Проверьте интернет.');
      }
    } catch (e) {
      ErrorHandler.logError('MasterAvailabilityScreen._loadAvailability', e);
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Если есть кеш - показываем его
        if (_availabilityList.isEmpty) {
          final cached = await _cache.getFromStorage<List>('availability_$_userId');
          if (cached != null && mounted) {
            setState(() => _availabilityList = List<Map<String, dynamic>>.from(cached));
            return;
          }
        }
        
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  void _showNetworkError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
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

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await _loadAvailability(forceRefresh: true);
  }

  Future<void> _openDateEditor() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD47926),
              onPrimary: Colors.white,
              surface: Color(0xFF444444),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !mounted) return;

    final normalizedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    setState(() => _selectedDate = normalizedDate);

    final existing = _availabilityList.firstWhere(
      (a) => a['date'] == DateFormat('yyyy-MM-dd').format(normalizedDate),
      orElse: () => {},
    );

    if (existing.isNotEmpty) {
      final startParts = existing['start_time'].toString().split(':');
      final endParts = existing['end_time'].toString().split(':');
      setState(() {
        _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
        _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
      });
    }
  }

  Future<void> _saveAvailability() async {
    if (_userId == null || !mounted) return;

    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;

    if (startMinutes >= endMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Время начала должно быть раньше времени окончания'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00';
    final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00';

    try {
      await Supabase.instance.client.from('availability').upsert({
        'barber_id': _userId!,
        'date': dateStr,
        'start_time': startStr,
        'end_time': endStr,
        'is_available': true,
      }, onConflict: 'barber_id, date');

      // 🔥 Очищаем кеш
      await _cache.clear('availability_$_userId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Расписание сохранено'), backgroundColor: Colors.green),
        );
        _loadAvailability(forceRefresh: true);
        Navigator.pop(context);
      }
    } catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  Future<void> _deleteAvailability(String dateStr) async {
    if (_userId == null) return;

    try {
      await Supabase.instance.client
          .from('availability')
          .delete()
          .eq('barber_id', _userId!)
          .eq('date', dateStr);

      await _cache.clear('availability_$_userId');
      _loadAvailability(forceRefresh: true);
    } catch (e) {
      ErrorHandler.showErrorSnackBar(context, e);
    }
  }

  Future<void> _showAddBottomSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF363636),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Выберите дату', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openDateEditor,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white54),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy', 'ru_RU').format(_selectedDate),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildTimePicker('Начало', _startTime, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTimePicker('Конец', _endTime, false)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAvailability,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD47926),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Сохранить', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, bool isStart) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(primary: Color(0xFFD47926), onPrimary: Colors.white),
              ),
              child: child!,
            );
          },
        );
        if (picked != null && mounted) {
          setState(() {
            if (isStart) {
              _startTime = picked;
            } else {
              _endTime = picked;
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF444444),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        title: const Text('Моя доступность', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _retry,
            tooltip: 'Обновить',
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showAddBottomSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _availabilityList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_available, size: 64, color: Colors.white24),
                      const SizedBox(height: 16),
                      const Text('Нет запланированных дней', style: TextStyle(color: Colors.white54)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showAddBottomSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить день'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD47926), foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAvailability(forceRefresh: true),
                  color: const Color(0xFFD47926),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availabilityList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _availabilityList[index];
                      final dateStr = item['date'] as String;
                      final date = DateTime.parse(dateStr);
                      final start = item['start_time'].toString().substring(0, 5);
                      final end = item['end_time'].toString().substring(0, 5);

                      return Dismissible(
                        key: Key(dateStr),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.delete, color: Colors.red),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: const Color(0xFF444444),
                              title: const Text('Удалить день?', style: TextStyle(color: Colors.white)),
                              content: const Text('Вы уверены, что хотите удалить это расписание?', style: TextStyle(color: Colors.white70)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена', style: TextStyle(color: Colors.white54))),
                                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) => _deleteAvailability(dateStr),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: const Color(0xFF555555), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  children: [
                                    Text(DateFormat('dd', 'ru_RU').format(date), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    Text(DateFormat('MMM', 'ru_RU').format(date).toUpperCase(), style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEEE', 'ru_RU').format(date),
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('$start – $end', style: TextStyle(color: Colors.white54, fontSize: 14)),
                                  ],
                                ),
                              ),
                              Icon(Icons.check_circle, color: const Color(0xFFD47926), size: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}