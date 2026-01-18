// lib/screens/service_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';
import 'master_list_screen.dart'; // ← новый экран (создадим ниже)

class ServiceScreen extends StatelessWidget {
  const ServiceScreen({super.key});

  Future<List<Map<String, dynamic>>> _fetchServices() async {
    final response = await Supabase.instance.client
        .from('services')
        .select('service_id, name, price, duration_min')
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TribeAppBar(
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            );
          }

          final services = snapshot.data ?? [];
          if (services.isEmpty) {
            return const Center(
              child: Text('Нет доступных услуг', style: TextStyle(color: Colors.white70)),
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
                      // Переход к списку мастеров, которые делают эту услугу
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MasterListScreen(
                            serviceId: s['service_id'],
                            serviceName: s['name'],
                            duration: s['duration_min'],
                          ),
                        ),
                      );
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