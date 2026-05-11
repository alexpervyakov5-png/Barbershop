import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/master/master_profile_screen.dart';
class TribeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TribeAppBar({super.key});

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
        IconButton(
          onPressed: () async {
            // ✅ УМНАЯ НАВИГАЦИЯ: проверяем роль перед переходом
            final session = Supabase.instance.client.auth.currentSession;
            if (session == null) {
              // Нет сессии → вход
              Navigator.pushNamed(context, '/login');
              return;
            }

            try {
              // Запрашиваем роль пользователя
              final response = await Supabase.instance.client
                  .from('users')
                  .select('role_id')
                  .eq('user_id', session.user.id)
                  .maybeSingle();

              final roleId = response?['role_id'] as int?;

              // ✅ Открываем нужный профиль в зависимости от роли
              if (roleId == 2) {
                // Мастер → МастерПрофиль
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
                // Админ → АдминПанель
                Navigator.pushNamed(context, '/admin');
              } else {
                // Клиент → КлиентПрофиль
                Navigator.pushNamed(context, '/profile');
              }
            } catch (e) {
              // При ошибке — показываем обычный профиль
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