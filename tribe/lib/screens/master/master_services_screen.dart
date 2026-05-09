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
  Set<int> _selectedServices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    
    try {
      // Загружаем все доступные услуги (только активные)
      final servicesResponse = await Supabase.instance.client
          .from('services')
          .select('service_id, name, description, is_active')
          .eq('is_active', true)
          .order('name');

      debugPrint('📋 Загружено услуг: ${servicesResponse.length}');

      // Загружаем выбранные услуги мастера
      final masterServicesResponse = await Supabase.instance.client
          .from('barber_services')
          .select('service_id')
          .eq('barber_id', widget.masterId);

      final selectedIds = masterServicesResponse
          .map((s) => s['service_id'] as int)
          .toSet();

      debugPrint('✅ Выбрано услуг мастером: ${selectedIds.length}');

      if (mounted) {
        setState(() {
          _allServices = List<Map<String, dynamic>>.from(servicesResponse);
          _selectedServices = selectedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._loadServices', e);
      debugPrint('❌ Ошибка загрузки услуг: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось загрузить услуги. Проверьте права доступа.',
        );
      }
    }
  }

  Future<void> _toggleService(int serviceId, bool isSelected) async {
    try {
      if (isSelected) {
        // Добавляем услугу
        await Supabase.instance.client.from('barber_services').insert({
          'barber_id': widget.masterId,
          'service_id': serviceId,
        });
        
        debugPrint('✅ Услуга $serviceId добавлена');
      } else {
        // Удаляем услугу
        await Supabase.instance.client
            .from('barber_services')
            .delete()
            .eq('barber_id', widget.masterId)
            .eq('service_id', serviceId);
        
        debugPrint('❌ Услуга $serviceId удалена');
      }

      if (mounted) {
        setState(() {
          if (isSelected) {
            _selectedServices.add(serviceId);
          } else {
            _selectedServices.remove(serviceId);
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isSelected ? '✅ Услуга добавлена' : 'Услуга удалена'),
            backgroundColor: isSelected ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      ErrorHandler.logError('MasterServicesScreen._toggleService', e);
      debugPrint('❌ Ошибка переключения услуги: $e');
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось изменить услугу',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Выберите услуги, которые вы предоставляете',
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
                          // ✅ ИСПРАВЛЕНО: используем существующую иконку
                          Icon(Icons.content_cut_outlined, size: 64, color: Colors.white24),
                          const SizedBox(height: 16),
                          const Text(
                            'Нет доступных услуг',
                            style: TextStyle(color: Colors.white54),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Обратитесь к администратору',
                            style: TextStyle(color: Colors.white38, fontSize: 12),
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
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFFD47926),
                                    size: 24,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}