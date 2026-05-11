import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ✅ Удалён неиспользуемый импорт: '../auth/login_screen.dart';
import '../utils/error_handler.dart';

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
  late final Future<Map<String, dynamic>?> _userData;
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _userData = _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _loadUserData() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return null;
      
      final userId = session.user.id;
      final response = await Supabase.instance.client
          .from('users')
          .select('full_name, email, phone, photo_url')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _fullNameController.text = response['full_name'] ?? '';
        _phoneController.text = response['phone'] ?? '';
      }

      return response;
    } catch (e) {
      ErrorHandler.logError('ProfileBottomSheet._loadUserData', e);
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_fullNameController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Имя обязательно')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) throw Exception('Не авторизован');
      
      final userId = session.user.id;
      
      await Supabase.instance.client
          .from('users')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
          })
          .eq('user_id', userId);

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Профиль обновлён')),
        );
      }
    } catch (e) {
      ErrorHandler.logError('ProfileBottomSheet._saveProfile', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось сохранить профиль',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    Navigator.pop(context);
    
    try {
      await Supabase.instance.client.auth.signOut();
    } on AuthRetryableFetchException catch (e) {
      debugPrint('⚠️ Network error during signOut: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } on AuthException catch (e) {
      debugPrint('⚠️ Auth error during signOut: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('⚠️ Unexpected error during signOut: $e');
      await Supabase.instance.client.auth.signOut(scope: SignOutScope.local);
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Профиль',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              if (!_isEditing)
                TextButton(
                  onPressed: () => setState(() => _isEditing = true),
                  child: const Text('Редактировать', style: TextStyle(color: Colors.blue)),
                ),
              if (_isEditing)
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                            )
                          : const Text('Готово', style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                shape: BoxShape.circle,
                // ✅ ИСПРАВЛЕНО: withValues вместо withOpacity
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<Map<String, dynamic>?>(
            future: _userData,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );
              }
              
              if (snapshot.hasError) {
                ErrorHandler.logError('ProfileBottomSheet.FutureBuilder', snapshot.error);
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        ErrorHandler.getErrorMessage(snapshot.error),
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Попробовать снова'),
                      ),
                    ],
                  ),
                );
              }

              final user = snapshot.data;
              if (user == null) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Не удалось загрузить данные', style: TextStyle(color: Colors.grey)),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['email'] ?? '—',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
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
          TextButton(
            onPressed: _isLoading ? null : _signOut,
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