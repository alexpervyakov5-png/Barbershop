import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import 'master_services_screen.dart';
import 'master_works_screen.dart';
import 'master_availability_screen.dart';

class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  int _currentIndex = 0;
  String? _masterName;
  String? _masterId;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _masterId = response['user_id'];
          _masterName = response['full_name'] ?? 'Мастер';
          
          // Инициализируем страницы после загрузки данных
          _pages.addAll([
            MasterServicesScreen(masterId: _masterId!),
            MasterWorksScreen(masterId: _masterId!, masterName: _masterName!),
            const MasterAvailabilityScreen(),
          ]);
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки данных мастера: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Показываем загрузку пока данные не загружены
    if (_masterId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        backgroundColor: const Color(0xFF363636),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.cut_outlined),
            activeIcon: Icon(Icons.cut),
            label: 'Сервисы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library_outlined),
            activeIcon: Icon(Icons.photo_library),
            label: 'Работы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),  // ✅ Иконка доступности
            activeIcon: Icon(Icons.schedule),
            label: 'Доступность',
          ),
        ],
      ),
    );
  }
}