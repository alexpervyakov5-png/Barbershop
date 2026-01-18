// lib/screens/master_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';

class MasterListScreen extends StatelessWidget {
  final int serviceId;
  final String serviceName;
  final int duration;

  const MasterListScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.duration,
  });

  Future<List<Map<String, dynamic>>> _fetchMastersForService(int serviceId) async {
    // 1. Найти barber_id из barber_services по service_id
    final barberServicesResponse = await Supabase.instance.client
        .from('barber_services')
        .select('barber_id')
        .eq('service_id', serviceId);

    final List<dynamic> barberServices = barberServicesResponse as List<dynamic>;
    if (barberServices.isEmpty) return [];

    final List<String> barberIds = barberServices
        .map((e) => e['barber_id'].toString())
        .toList();

    // 2. Получить данные мастеров из users
    final mastersResponse = await Supabase.instance.client
        .from('users')
        .select('user_id, full_name, phone')
        .inFilter('user_id', barberIds)
        .eq('role_id', 2); // только барберы

    return List<Map<String, dynamic>>.from(mastersResponse);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TribeAppBar(
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMastersForService(serviceId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final masters = snapshot.data ?? [];
          if (masters.isEmpty) {
            return const Center(
              child: Text('Нет мастеров для этой услуги', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: masters.length,
            itemBuilder: (context, index) {
              final m = masters[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(m['full_name'] ?? 'Мастер', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(m['phone'] ?? '', style: const TextStyle(color: Colors.grey)),
                    onTap: () {
                      // TODO: Перейти к выбору времени
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Выбран мастер: ${m['full_name']}')),
                      );
                      // Позже: Navigator.push(... AppointmentTimeScreen ...)
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