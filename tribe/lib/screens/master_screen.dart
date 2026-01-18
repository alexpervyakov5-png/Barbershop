// lib/screens/master_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';

class MasterScreen extends StatelessWidget {
  const MasterScreen({super.key});

  Future<List<dynamic>> _fetchBarbers() async {
    final response = await Supabase.instance.client
        .from('users')
        .select('user_id, full_name, phone')
        .eq('role_id', 2);

    print('✅ Получено мастеров: ${response.length}');
    return response;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TribeAppBar(

      ),
      body: FutureBuilder<List<dynamic>>(
        future: _fetchBarbers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }
          if (snapshot.hasError) {
            print('❌ Ошибка: ${snapshot.error}');
            return Center(
              child: Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
            );
          }

          final barbers = snapshot.data ?? [];
          print('🖨️ Список мастеров: $barbers');

          if (barbers.isEmpty) {
            return const Center(
              child: Text('Нет мастеров', style: TextStyle(color: Colors.white70)),
            );
          }

          return ListView.builder(
            itemCount: barbers.length,
            itemBuilder: (context, index) {
              final barber = barbers[index];
              final name = barber['full_name'] ?? 'Без имени';
              final phone = barber['phone'] ?? '';
              final id = barber['user_id'];

              return ListTile(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                subtitle: Text(phone, style: const TextStyle(color: Colors.grey)),
                onTap: () => print('Выбран мастер: $name, ID: $id'),
              );
            },
          );
        },
      ),
    );
  }
}