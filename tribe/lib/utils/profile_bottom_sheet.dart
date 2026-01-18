// lib/utils/profile_bottom_sheet.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';

void showProfileBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF363636),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const ProfileBottomSheetContent(),
  );
}

class ProfileBottomSheetContent extends StatefulWidget {
  const ProfileBottomSheetContent({super.key});

  @override
  State<ProfileBottomSheetContent> createState() =>
      _ProfileBottomSheetContentState();
}

class _ProfileBottomSheetContentState extends State<ProfileBottomSheetContent> {
  late final Future<Map<String, dynamic>> _userData;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _userData = _loadUserData();
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    final userId = Supabase.instance.client.auth.currentSession!.user.id;
    final response = await Supabase.instance.client
        .from('users')
        .select('full_name, email, phone')
        .eq('user_id', userId)
        .single();

    _fullNameController.text = response['full_name'] ?? '';
    _phoneController.text = response['phone'] ?? '';

    return response;
  }

  Future<void> _saveProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя обязательно')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentSession!.user.id;
    await Supabase.instance.client
        .from('users')
        .update({
          'full_name': _fullNameController.text.trim(),
          'phone': _phoneController.text.trim(),
        })
        .eq('user_id', userId);

    setState(() {
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сохранено')),
    );
  }

  Future<void> _signOut() async {
    Navigator.pop(context); // закрыть bottom sheet
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Профиль',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!_isEditing)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                    });
                  },
                  child: const Text('Редактировать', style: TextStyle(color: Colors.blue)),
                ),
              if (_isEditing)
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                        });
                      },
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: _saveProfile,
                      child: const Text('Готово', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Иконка профиля (заглушка)
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 16),

          // Данные
          FutureBuilder<Map<String, dynamic>>(
            future: _userData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              }
              if (snapshot.hasError) {
                return Text('Ошибка: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              final user = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email (всегда для чтения)
                  Text(
                    user['email'] ?? '—',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Имя
                  if (_isEditing)
                    TextField(
                      controller: _fullNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Имя *',
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    )
                  else
                    Text(
                      _fullNameController.text.isEmpty ? '—' : _fullNameController.text,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),

                  const SizedBox(height: 12),

                  // Телефон
                  if (_isEditing)
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Телефон',
                        labelStyle: const TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                    )
                  else
                    Text(
                      _phoneController.text.isEmpty ? '—' : _phoneController.text,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                ],
              );
            },
          ),

          const Spacer(),

          // Кнопка выхода
          TextButton(
            onPressed: _signOut,
            child: const Text(
              'Выйти из аккаунта',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}