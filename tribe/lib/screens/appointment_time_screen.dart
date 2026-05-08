import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../widgets/tribe_app_bar.dart';

class AppointmentTimeScreen extends StatefulWidget {
  final String masterId;
  final String masterName;
  final int? serviceId;
  final String? serviceName;
  final List<int>? serviceIds;
  final int? duration;
  final int? totalDuration;

  const AppointmentTimeScreen({
    super.key,
    required this.masterId,
    required this.masterName,
    this.serviceId,
    this.serviceName,
    this.serviceIds,
    this.duration,
    this.totalDuration,
  });

  @override
  State<AppointmentTimeScreen> createState() => _AppointmentTimeScreenState();
}

class _AppointmentTimeScreenState extends State<AppointmentTimeScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  DateTime? _nearestAvailableDay;
  Map<DateTime, List<String>> _availableSlots = {};
  bool _isLoading = true;
  String? _selectedTime;

  // ✅ Вычисляем длительность один раз
  int get _serviceDuration => widget.totalDuration ?? widget.duration ?? 60;

  final Map<String, List<String>> _timeGroups = {
    'Утро': ['10:00', '11:00'],
    'День': ['12:00', '13:00', '14:00', '15:00', '16:00', '17:00'],
    'Вечер': ['18:00', '19:00', '19:45', '20:00'],
  };

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru', null);
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final slots = await _fetchAvailableSlots(widget.masterId, _selectedDay, _serviceDuration);
      
      if (mounted) {
        setState(() {
          _availableSlots = slots;
          _nearestAvailableDay = _findNearestAvailableDay(slots);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Ошибка загрузки доступности: $e');
    }
  }

  // ✅ Исправленная логика: строгая проверка пересечений по времени
  Future<Map<DateTime, List<String>>> _fetchAvailableSlots(
    String barberId,
    DateTime day,
    int durationMinutes,
  ) async {
    try {
      final dateString = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      
      final availabilityResponse = await Supabase.instance.client
          .from('availability')
          .select('start_time, end_time')
          .eq('barber_id', barberId)
          .eq('date', dateString)
          .eq('is_available', true)
          .order('start_time');

      if (availabilityResponse.isEmpty) return {};

      // Загружаем уже забронированные слоты
      final appointmentsResponse = await Supabase.instance.client
          .from('appointments')
          .select('start_datetime, end_datetime')
          .eq('barber_id', barberId)
          .eq('status', 'забронировано')
          .gte('start_datetime', '$dateString 00:00:00')
          .lte('start_datetime', '$dateString 23:59:59');

      // Формируем список существующих записей для проверки пересечений
      final List<Map<String, DateTime>> existing = [];
      for (var appt in appointmentsResponse) {
        existing.add({
          'start': DateTime.parse(appt['start_datetime']),
          'end': DateTime.parse(appt['end_datetime']),
        });
      }
      existing.sort((a, b) => a['start']!.compareTo(b['start']!));

      final availableSlots = <String>[];
      
      for (var slot in availabilityResponse) {
        final startTime = slot['start_time'] as String;
        final endTime = slot['end_time'] as String;
        
        final startParts = startTime.split(':');
        final endParts = endTime.split(':');
        
        var currH = int.parse(startParts[0]);
        var currM = int.parse(startParts[1]);
        final endH = int.parse(endParts[0]);
        final endM = int.parse(endParts[1]);
        
        final workSlotEndDt = DateTime(day.year, day.month, day.day, endH, endM);

        while (currH < endH || (currH == endH && currM < endM)) {
          final timeStr = '${currH.toString().padLeft(2, '0')}:${currM.toString().padLeft(2, '0')}';
          
          // Рассчитываем интервал новой записи
          final candidateStart = DateTime(day.year, day.month, day.day, currH, currM);
          final candidateEnd = candidateStart.add(Duration(minutes: durationMinutes));

          // 1. Если запись не помещается в рабочий слот мастера -> останавливаем генерацию для этого слота
          if (candidateEnd.isAfter(workSlotEndDt)) break;

          // 2. Проверяем пересечение с существующими записями
          bool isAvailable = true;
          for (var appt in existing) {
            // Условие пересечения: !(конец_новой <= начало_существ || начало_новой >= конец_существ)
            if (candidateEnd.isAfter(appt['start']!) && candidateStart.isBefore(appt['end']!)) {
              isAvailable = false;
              break;
            }
          }

          if (isAvailable) {
            availableSlots.add(timeStr);
          }
          
          currM += 15;
          if (currM >= 60) {
            currM = 0;
            currH++;
          }
        }
      }

      final normalizedDay = DateTime(day.year, day.month, day.day);
      return {normalizedDay: availableSlots};
      
    } catch (e) {
      debugPrint('Ошибка при загрузке слотов: $e');
      return {};
    }
  }

  DateTime? _findNearestAvailableDay(Map<DateTime, List<String>> slots) {
    for (var i = 1; i <= 30; i++) {
      final nextDay = DateTime.now().add(Duration(days: i));
      final normalizedDay = DateTime(nextDay.year, nextDay.month, nextDay.day);
      
      if (slots.containsKey(normalizedDay) && slots[normalizedDay]!.isNotEmpty) {
        return normalizedDay;
      }
    }
    return null;
  }

  List<String> _getAvailableSlotsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _availableSlots[normalizedDay] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!mounted) return;
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedTime = null;
    });
    _loadAvailability();
  }

  void _goToNearestDate() {
    if (_nearestAvailableDay != null && mounted) {
      setState(() {
        _selectedDay = _nearestAvailableDay!;
        _focusedDay = _nearestAvailableDay!;
      });
      _loadAvailability();
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите время'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final selectedDateTime = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        int.parse(_selectedTime!.split(':')[0]),
        int.parse(_selectedTime!.split(':')[1]),
      );

      final endDateTime = selectedDateTime.add(Duration(minutes: _serviceDuration));

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      await Supabase.instance.client.from('appointments').insert({
        'polzovatel_id': userId,
        'barber_id': widget.masterId,
        'service_id': widget.serviceId,
        'start_datetime': selectedDateTime.toIso8601String(),
        'end_datetime': endDateTime.toIso8601String(),
        'status': 'забронировано',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF444444),
            title: const Text('Запись подтверждена', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Мастер: ${widget.masterName}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Дата: ${_selectedDay.day} мая', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Время: $_selectedTime', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text('Длительность: ~${(_serviceDuration / 60).toStringAsFixed(1)} ч ($_serviceDuration мин)', 
                     style: const TextStyle(color: Colors.white70)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка при создании записи: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании записи: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableSlots = _getAvailableSlotsForDay(_selectedDay);
    final hasNoSlots = availableSlots.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              locale: 'ru_RU',
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.monday,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white54),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white54),
              ),
              calendarStyle: const CalendarStyle(
                outsideTextStyle: TextStyle(color: Colors.white24),
                defaultTextStyle: TextStyle(color: Colors.white),
                selectedTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                todayTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                weekendTextStyle: TextStyle(color: Colors.white54),
                holidayTextStyle: TextStyle(color: Colors.white54),
                
                defaultDecoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                todayDecoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFFD47926),
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                outsideDecoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                weekendDecoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                holidayDecoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                markerDecoration: BoxDecoration(
                  color: Color(0xFFD47926),
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(color: Colors.white54, fontSize: 12),
                weekendStyle: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),

          Expanded(
            child: hasNoSlots && !_isLoading
                ? _buildNoAvailabilityWidget()
                : _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : _buildTimeSlotsWidget(availableSlots),
          ),

          if (!hasNoSlots && !_isLoading && _selectedTime != null)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              color: const Color(0xFF363636),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _confirmBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Подтвердить запись',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNoAvailabilityWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF444444),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy,
                color: Colors.white54,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'В этот день нет свободного времени',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ближайшая доступная дата:',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (_nearestAvailableDay != null)
              Text(
                _formatDate(_nearestAvailableDay!),
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            const SizedBox(height: 24),
            if (_nearestAvailableDay != null)
              ElevatedButton(
                onPressed: _goToNearestDate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD47926),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Перейти к ближайшей дате',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotsWidget(List<String> slots) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _timeGroups.entries.map((entry) {
          final groupTime = entry.value.where(slots.contains).toList();
          if (groupTime.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: groupTime.map((time) {
                    final isSelected = _selectedTime == time;
                    return GestureDetector(
                      onTap: () {
                        if (mounted) {
                          setState(() => _selectedTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD47926) : const Color(0xFF444444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          time,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 15,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${date.day} мая';
  }
}