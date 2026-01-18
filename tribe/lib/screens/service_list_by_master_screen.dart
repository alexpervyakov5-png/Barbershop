// lib/screens/service_list_by_master_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';

class ServiceListByMasterScreen extends StatelessWidget {
  final dynamic barberId; // может быть String или UUID

  const ServiceListByMasterScreen({super.key, required this.barberId});

  Future<List<Map<String, dynamic>>> _fetchServicesForBarber(dynamic barberId) async {
    final barberServicesResponse = await Supabase.instance.client
        .from('barber_services')
        .select('service_id')
        .eq('barber_id', barberId);

    final List<dynamic> barberServices = barberServicesResponse as List<dynamic>;
    if (barberServices.isEmpty) return [];

    final List<int> serviceIds = barberServices
        .map((e) => e['service_id'] as int)
        .toList();

    final servicesResponse = await Supabase.instance.client
        .from('services')
        .select('service_id, name, price, duration_min')
        .inFilter('service_id', serviceIds);

    return List<Map<String, dynamic>>.from(servicesResponse);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TribeAppBar(
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchServicesForBarber(barberId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return const Center(
              child: Text('Нет услуг у этого мастера', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final s = services[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(s['name'], style: const TextStyle(color: Colors.white, fontSize: 18)),
                    subtitle: Text('${s['price']} ₽ • ${s['duration_min']} мин',
                        style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Выбрана услуга: ${s['name']}')),
                      );
                      // TODO: Перейти к выбору времени
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}