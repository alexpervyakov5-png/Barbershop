import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/master/master_profile_screen.dart';
import '../screens/admin/admin_profile_screen.dart';
import '../utils/cache_service.dart';

class TribeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showProfileIcon;

  const TribeAppBar({
    super.key,
    this.showProfileIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF363636),
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/icons/icon_tribe.png',
            height: 36,
            width: 36,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.cut,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/icons/TRIBE.png',
            height: 28,
            width: 100,
            errorBuilder: (_, __, ___) => const Text(
              'TRIBE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (showProfileIcon)
          IconButton(
            onPressed: () async {
              final session = Supabase.instance.client.auth.currentSession;
              if (session == null) {
                Navigator.pushNamed(context, '/login');
                return;
              }

              try {
                // 🔥 Кеширование роли пользователя
                final cache = CacheService();
                int? roleId = cache.get<int>('user_role_${session.user.id}');

                if (roleId == null) {
                  final response = await Supabase.instance.client
                      .from('users')
                      .select('role_id')
                      .eq('user_id', session.user.id)
                      .maybeSingle()
                      .timeout(const Duration(seconds: 5));

                  roleId = response?['role_id'] as int?;

                  if (roleId != null) {
                    await cache.set('user_role_${session.user.id}', roleId,
                        duration: const Duration(minutes: 30));
                  }
                }

                if (roleId == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MasterProfileScreen(
                        masterId: session.user.id,
                        masterName: session.user.userMetadata?['full_name'] ?? 'Мастер',
                      ),
                    ),
                  );
                } else if (roleId == 3) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminProfileScreen(),
                    ),
                  );
                } else {
                  Navigator.pushNamed(context, '/profile');
                }
              } catch (e) {
                debugPrint('❌ Ошибка получения роли: $e');
                Navigator.pushNamed(context, '/profile');
              }
            },
            icon: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 26,
            ),
            padding: const EdgeInsets.only(right: 8),
          ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}