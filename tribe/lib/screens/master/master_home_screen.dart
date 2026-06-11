import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'master_services_screen.dart';  // ✅ Правильно (в той же папке)    // ✅ Правильно (в той же папке)
import 'master_availability_screen.dart'; // ✅ Правильно (в той же папке)
import '../../widgets/tribe_app_bar.dart';
import '../master_works_screen.dart';
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  int _currentIndex = 0;
  String? _masterId;
  String? _masterName;

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_masterId == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(showProfileIcon: true),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MasterServicesScreen(masterId: _masterId!),
          MasterWorksScreen(
            masterId: _masterId!,
            masterName: _masterName!,
            canEdit: true,
            showAppBar: false,
          ),
          const MasterAvailabilityScreen(),
        ],
      ),
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
            icon: Icon(Icons.schedule_outlined),
            activeIcon: Icon(Icons.schedule),
            label: 'Доступность',
          ),
        ],
      ),
    );
  }
}