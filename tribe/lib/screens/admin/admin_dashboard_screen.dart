import 'package:flutter/material.dart';
import 'manage_masters_screen.dart';
import 'manage_services_screen.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/role_helper.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isAuthorized = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
  }

  Future<void> _checkAdminRole() async {
    final isAdmin = await RoleHelper.requireAdmin();
    
    if (mounted) {
      if (!isAdmin) {
        Navigator.of(context).pushReplacementNamed('/');
      } else {
        setState(() {
          _isAuthorized = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!_isAuthorized) {
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(
          child: Text('Доступ запрещен', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Панель администратора',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Управление мастерами и услугами',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 32),

            _buildActionCard(
              title: 'Мастера',
              description: 'Добавлять, редактировать, блокировать',
              icon: Icons.person_add,
              color: const Color(0xFF4A90E2),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageMastersScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              title: 'Услуги',
              description: 'Создавать и редактировать каталог',
              icon: Icons.cut,
              color: const Color(0xFFD47926),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageServicesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF444444),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}