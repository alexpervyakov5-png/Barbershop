import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/error_handler.dart';
import 'appointment_time_screen.dart';

class ServiceListByMasterScreen extends StatelessWidget {
  final String barberId;
  final String masterName;
  final List<int> selectedServiceIds; // ✅ Обязательно: пользователь уже выбрал услуги

  const ServiceListByMasterScreen({
    super.key,
    required this.barberId,
    required this.masterName,
    required this.selectedServiceIds,
  });

  Future<List<Map<String, dynamic>>> _fetchSelectedServices() async {
    if (selectedServiceIds.isEmpty) return [];

    try {
      // ✅ Загружаем ТОЛЬКО те услуги, которые выбрал пользователь + цены мастера
      final response = await Supabase.instance.client
          .from('master_services')
          .select('service_id, price, duration_min')
          .eq('barber_id', barberId)
          .inFilter('service_id', selectedServiceIds);

      if (response.isEmpty) return [];

      // Загружаем названия услуг
      final servicesResponse = await Supabase.instance.client
          .from('services')
          .select('service_id, name, description')
          .inFilter('service_id', selectedServiceIds);

      final Map<int, String> serviceNames = {};
      final Map<int, String> serviceDesc = {};
      for (var s in servicesResponse) {
        serviceNames[s['service_id'] as int] = s['name'] as String;
        serviceDesc[s['service_id'] as int] = s['description'] as String? ?? '';
      }

      // Собираем финальный список
      final result = response.map((item) {
        final serviceId = item['service_id'] as int;
        return {
          'service_id': serviceId,
          'name': serviceNames[serviceId] ?? 'Услуга',
          'description': serviceDesc[serviceId],
          'price': item['price'],
          'duration_min': item['duration_min'] ?? 60,
        };
      }).toList();

      // Сортировка по порядку выбора (опционально)
      result.sort((a, b) => 
        selectedServiceIds.indexOf(a['service_id'])
            .compareTo(selectedServiceIds.indexOf(b['service_id']))
      );

      return result;
    } catch (e) {
      ErrorHandler.logError('ServiceListByMasterScreen._fetchSelectedServices', e);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        title: Text(
          masterName,
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchSelectedServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            ErrorHandler.logError('ServiceListByMasterScreen.build', snapshot.error!);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.white54),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.getErrorMessage(snapshot.error),
                      style: const TextStyle(color: Colors.white54),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Назад'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD47926),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Мастер не оказывает выбранные услуги',
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD47926),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Выбрать другого мастера'),
                  ),
                ],
              ),
            );
          }

          // ✅ Считаем итоговую сумму и время
          final totalPrice = services.fold<int>(
            0,
            (sum, s) => sum + ((s['price'] as num?)?.toInt() ?? 0),
          );
          final totalDuration = services.fold<int>(
            0,
            (sum, s) => sum + (s['duration_min'] as int),
          );

          return Column(
            children: [
              // Заголовок с итогом
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFF444444),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выбранные услуги',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$totalDuration мин',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$totalPrice ₽',
                          style: const TextStyle(
                            color: Color(0xFFD47926),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Список услуг (только просмотр, без выбора)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return _ServiceSummaryCard(
                      name: s['name'],
                      description: s['description'],
                      price: s['price'],
                      duration: s['duration_min'],
                    );
                  },
                ),
              ),

              // Кнопка записи
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                color: const Color(0xFF363636),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentTimeScreen(
                            masterId: barberId,
                            masterName: masterName,
                            serviceIds: selectedServiceIds,
                            totalDuration: totalDuration,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF363636),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Записаться на $totalDuration мин за $totalPrice ₽',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ✅ Карточка только для просмотра (без чекбокса)
class _ServiceSummaryCard extends StatelessWidget {
  final String name;
  final String? description;
  final dynamic price;
  final int duration;

  const _ServiceSummaryCard({
    required this.name,
    required this.description,
    required this.price,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null && description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price != null 
                    ? '${(price as num).toInt()} ₽' 
                    : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$duration мин',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}