import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/error_handler.dart';

class MasterAvailabilityScreen extends StatefulWidget {
  const MasterAvailabilityScreen({super.key});

  @override
  State<MasterAvailabilityScreen> createState() => _MasterAvailabilityScreenState();
}

class _MasterAvailabilityScreenState extends State<MasterAvailabilityScreen> {
  bool _isAvailable = true;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  List<String> _workingDays = [];
  bool _isLoading = true;

  final List<String> _daysOfWeek = [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
    'Воскресенье',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('users')
          .select('is_active, work_start_time, work_end_time, working_days')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _isAvailable = response['is_active'] ?? true;
          _workingDays = response['working_days'] != null
              ? List<String>.from(response['working_days'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('MasterAvailabilityScreen._loadAvailability', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _saveAvailability() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Не авторизован');

      await Supabase.instance.client
          .from('users')
          .update({
            'is_active': _isAvailable,
            'working_days': _workingDays,
          })
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Настройки сохранены'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ErrorHandler.logError('MasterAvailabilityScreen._saveAvailability', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  void _toggleDay(String day) {
    setState(() {
      if (_workingDays.contains(day)) {
        _workingDays.remove(day);
      } else {
        _workingDays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Статус доступности
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Статус доступности',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isAvailable 
                                  ? 'Вы принимаете записи' 
                                  : 'Вы не принимаете записи',
                              style: TextStyle(
                                color: _isAvailable ? Colors.green : Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isAvailable,
                        onChanged: (value) {
                          setState(() => _isAvailable = value);
                          _saveAvailability();
                        },
                        activeColor: const Color(0xFFD47926),
                        activeTrackColor: const Color(0xFFD47926).withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Рабочие дни
                const Text(
                  'Рабочие дни',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _daysOfWeek.map((day) {
                    final isSelected = _workingDays.contains(day);
                    return ChoiceChip(
                      label: Text(day),
                      selected: isSelected,
                      onSelected: (selected) => _toggleDay(day),
                      selectedColor: const Color(0xFFD47926),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                      backgroundColor: const Color(0xFF444444),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Кнопка сохранения
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saveAvailability,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD47926),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Сохранить настройки',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          );
  }
}