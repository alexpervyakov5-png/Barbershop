import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Map<String, dynamic>? _admin;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, created_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _admin = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('AdminProfileScreen._loadProfile', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Выход', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Вы уверены, что хотите выйти из аккаунта?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthRetryableFetchException {
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('❌ Ошибка при выходе: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      // ✅ ИСПРАВЛЕНО: Кнопка профиля здесь скрыта
      appBar: const TribeAppBar(showProfileIcon: false),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Профиль администратора',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF444444),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF555555),
                            shape: BoxShape.circle,
                          ),
                          child: _admin?['photo_url'] != null &&
                                  _admin!['photo_url'].toString().isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _admin!['photo_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                                  ),
                                )
                              : _buildInitialsAvatar(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _admin?['full_name'] ?? 'Администратор',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD47926).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Администратор',
                            style: TextStyle(
                              color: Color(0xFFD47926),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.email_outlined, 'Email', _admin?['email'] ?? '—'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.phone_outlined, 'Телефон', _admin?['phone'] ?? '—'),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.calendar_today_outlined, 'Дата регистрации', _formatDate(_admin?['created_at'])),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text(
                    'Быстрые действия',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),

                  _buildQuickAction(
                    icon: Icons.people,
                    title: 'Управление мастерами',
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                  ),
                  const SizedBox(height: 12),
                  _buildQuickAction(
                    icon: Icons.cut,
                    title: 'Управление услугами',
                    onTap: () => Navigator.pushNamed(context, '/admin'),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Выйти из аккаунта',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInitialsAvatar() {
    final name = _admin?['full_name'] as String? ?? 'A';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    return Center(
      child: Text(
        initial,
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF444444),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFD47926), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}