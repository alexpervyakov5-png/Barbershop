import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'appointment_time_screen.dart';

class ServiceListByMasterScreen extends StatelessWidget {
  final String barberId;
  final String masterName;
  final List<int>? selectedServiceIds;

  const ServiceListByMasterScreen({
    super.key,
    required this.barberId,
    this.masterName = 'Мастер',
    this.selectedServiceIds,
  });

  Future<List<Map<String, dynamic>>> _fetchServicesForBarber() async {
    final response = await Supabase.instance.client
        .from('barber_services')
        .select('service_id, price, duration_min')
        .eq('barber_id', barberId);

    if (response.isEmpty) return [];

    final serviceIds = response.map((e) => e['service_id'] as int).toList();
    final servicesResponse = await Supabase.instance.client
        .from('services')
        .select('service_id, name')
        .inFilter('service_id', serviceIds);

    final Map<int, String> serviceNames = {};
    for (var s in servicesResponse) {
      serviceNames[s['service_id'] as int] = s['name'] as String;
    }

    final allServices = response.map((item) {
      final serviceId = item['service_id'] as int;
      return {
        'service_id': serviceId,
        'name': serviceNames[serviceId] ?? 'Услуга',
        'price': item['price'],
        'duration_min': item['duration_min'] ?? 0,
      };
    }).toList();

    allServices.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if (selectedServiceIds != null && selectedServiceIds!.isNotEmpty) {
      return allServices
          .where((s) => selectedServiceIds!.contains(s['service_id'] as int))
          .toList();
    }

    return allServices;
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
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchServicesForBarber(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            final message = (selectedServiceIds != null && selectedServiceIds!.isNotEmpty)
                ? 'Мастер не оказывает выбранные услуги'
                : 'Нет услуг';
            return Center(
              child: Text(message, style: const TextStyle(color: Colors.white70)),
            );
          }

          final totalDuration = services.fold<int>(
            0,
            (sum, s) => sum + (s['duration_min'] as int),
          );

          final bool isSingle = selectedServiceIds != null && selectedServiceIds!.length == 1;
          final int? sid = isSingle ? selectedServiceIds!.first : null;
          final String? sname = (isSingle && services.isNotEmpty) ? services.first['name'] as String? : null;
          final int? sdur = (isSingle && services.isNotEmpty) ? services.first['duration_min'] as int? : null;

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return _ServiceCard(
                      name: s['name'],
                      price: s['price'],
                      duration: s['duration_min'],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                color: const Color(0xFF363636),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentTimeScreen(
                            masterId: barberId,
                            masterName: masterName,
                            serviceIds: selectedServiceIds,
                            serviceId: sid,
                            serviceName: sname,
                            totalDuration: totalDuration,
                            duration: sdur,
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
                      'Записаться на $totalDuration мин',
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

class _ServiceCard extends StatelessWidget {
  final String name;
  final dynamic price;
  final int duration;

  const _ServiceCard({
    required this.name,
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
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price != null 
                    ? '${double.parse(price.toString()).toStringAsFixed(0)} ₽' 
                    : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$duration мин',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}