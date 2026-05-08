// lib/widgets/tribe_app_bar.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          onPressed: () {
            final session = Supabase.instance.client.auth.currentSession;
            if (session != null) {
              Navigator.pushNamed(context, '/profile');
            } else {
              Navigator.pushNamed(context, '/login');
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