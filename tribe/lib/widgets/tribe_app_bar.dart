// lib/widgets/tribe_app_bar.dart
import 'package:flutter/material.dart';
// import '../profile/profile_screen.dart';
import '../utils/profile_bottom_sheet.dart';
// lib/widgets/tribe_app_bar.dart

class TribeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TribeAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFF363636),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/icon_tribe.png', height: 36, width: 36),
          const SizedBox(width: 8),
          Image.asset('assets/icons/TRIBE.png', height: 28, width: 100),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          onPressed: () {
            // Открываем плашку профиля
            showProfileBottomSheet(context);
          },
          icon: Image.asset('assets/icons/menu.png', height: 24, width: 24),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}