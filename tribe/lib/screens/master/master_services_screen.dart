import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/error_handler.dart';

class MasterServicesScreen extends StatefulWidget {
  final String masterId;

  const MasterServicesScreen({
    super.key,
    required this.masterId,
  });

  @override
  State<MasterServicesScreen> createState() => _MasterServicesScreenState();
}

class _MasterServicesScreenState extends State<MasterServicesScreen> {
  List<Map<String, dynamic>> _allServices = [];
  Map<int, Map<String, dynamic>> _masterServiceData = {}; // service_id → {price, duration_min}
  Set<int> _selectedServices = {};
  bool _isLoading = true;
  bool _isSaving = false;

  // Контроллеры для редактирования (временные, для текущего редактируемого сервиса)
  int? _editingServiceId;
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Загружаем все доступные услуги (только активные)
      final servicesResponse = await Supabase.instance.client
          .from('services')
          .select('service_id, name, description, is_active')
          .eq('is_active', true)
          .order('name');

      debugPrint('📋 Загружено услуг: ${servicesResponse.length}');

      // 2. Загружаем настройки мастера для этих услуг (цена, длительность)
      final masterServicesResponse = await Supabase.instance.client
          .from('master_services')
          .select('service_id, price, duration_min')
          .eq('barber_id', widget.masterId);

      debugPrint('✅ Настроек мастера: ${masterServicesResponse.length}');

      // 3. Собираем данные
      final Map<int, Map<String, dynamic>> masterData = {};
      final Set<int> selectedIds = {};
      
      for (var item in masterServicesResponse) {
        final serviceId = item['service_id'] as int;
        masterData[serviceId] = {
          'price': item['price'],
          'duration_min': item['duration_min'],
        };
        selectedIds.add(serviceId);
      }

      if (mounted) {
        setState(() {
          _allServices = List<Map<String, dynamic>>.from(servicesResponse);
          _masterServiceData = masterData;
          _selectedServices = selectedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._loadServices', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось загрузить услуги',
        );
      }
    }
  }

  /// ✅ Открывает диалог для редактирования цены и длительности
  void _openEditDialog(int serviceId, String serviceName) {
    final currentData = _masterServiceData[serviceId];
    
    _editingServiceId = serviceId;
    _priceController.text = currentData?['price']?.toString() ?? '1000';
    _durationController.text = currentData?['duration_min']?.toString() ?? '30';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: Text(
          serviceName,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Цена
            TextField(
              controller: _priceController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Цена (₽)',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money, color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            // Длительность
            TextField(
              controller: _durationController,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Длительность (мин)',
                labelStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => _saveServiceSettings(serviceId),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD47926),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ).then((_) {
      _editingServiceId = null;
      _priceController.clear();
      _durationController.clear();
    });
  }

  /// ✅ Сохраняет настройки услуги в БД
  Future<void> _saveServiceSettings(int serviceId) async {
    final price = int.tryParse(_priceController.text.trim());
    final duration = int.tryParse(_durationController.text.trim());

    if (price == null || duration == null || price <= 0 || duration <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Введите корректные значения'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      // Обновляем или создаём запись в master_services
      await Supabase.instance.client.from('master_services').upsert({
        'barber_id': widget.masterId,
        'service_id': serviceId,
        'price': price,
        'duration_min': duration,
      }, onConflict: 'barber_id,service_id');

      // Обновляем локальное состояние
      if (mounted) {
        setState(() {
          _masterServiceData[serviceId] = {
            'price': price,
            'duration_min': duration,
          };
          _selectedServices.add(serviceId);
        });

        Navigator.pop(context); // Закрываем диалог
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Настройки сохранены'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._saveServiceSettings', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось сохранить настройки',
        );
      }
    }
  }

  /// ✅ Переключает услугу (включает/выключает)
  Future<void> _toggleService(int serviceId, bool isSelected) async {
    try {
      if (isSelected) {
        // При включении — открываем диалог для настройки цены/времени
        final serviceName = _allServices.firstWhere(
          (s) => s['service_id'] == serviceId,
          orElse: () => {'name': 'Услуга'},
        )['name'] as String;
        
        _openEditDialog(serviceId, serviceName);
      } else {
        // При выключении — удаляем из master_services
        await Supabase.instance.client
            .from('master_services')
            .delete()
            .eq('barber_id', widget.masterId)
            .eq('service_id', serviceId);

        if (mounted) {
          setState(() {
            _masterServiceData.remove(serviceId);
            _selectedServices.remove(serviceId);
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Услуга удалена'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._toggleService', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось изменить услугу',
        );
      }
    }
  }

  /// ✅ Массовое сохранение всех изменений (опционально)
  Future<void> _saveAllChanges() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      // Для каждой выбранной услуги обновляем данные
      for (final serviceId in _selectedServices) {
        final data = _masterServiceData[serviceId];
        if (data != null) {
          await Supabase.instance.client.from('master_services').upsert({
            'barber_id': widget.masterId,
            'service_id': serviceId,
            'price': data['price'],
            'duration_min': data['duration_min'],
          }, onConflict: 'barber_id,service_id');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Все изменения сохранены'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._saveAllChanges', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось сохранить изменения',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        title: const Text('Мои услуги', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveAllChanges,
              tooltip: 'Сохранить все изменения',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Выберите услуги и настройте цену/время',
              style: TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _allServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.content_cut_outlined, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            const Text(
                              'Нет доступных услуг',
                              style: TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _allServices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = _allServices[index];
                          final serviceId = service['service_id'] as int;
                          final isSelected = _selectedServices.contains(serviceId);
                          final serviceData = _masterServiceData[serviceId];

                          return GestureDetector(
                            onTap: () => _toggleService(serviceId, !isSelected),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? const Color(0xFF505050) 
                                    : const Color(0xFF444444),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFFD47926) 
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          service['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (service['description'] != null && 
                                            service['description'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              service['description'],
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        // ✅ Показываем цену и время, если услуга выбрана
                                        if (isSelected && serviceData != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Row(
                                              children: [
                                                Chip(
                                                  label: Text(
                                                    '${serviceData['price']} ₽',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  backgroundColor: const Color(0xFFD47926),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                    '${serviceData['duration_min']} мин',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  backgroundColor: Colors.white24,
                                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                                  visualDensity: VisualDensity.compact,
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                                                  onPressed: () => _openEditDialog(
                                                    serviceId, 
                                                    service['name'] as String
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  tooltip: 'Редактировать',
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // ✅ Чекбокс выбора
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFD47926) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFFD47926) : Colors.white54,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}