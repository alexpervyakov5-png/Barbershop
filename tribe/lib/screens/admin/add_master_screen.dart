import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';

class AddMasterScreen extends StatefulWidget {
  const AddMasterScreen({super.key});

  @override
  State<AddMasterScreen> createState() => _AddMasterScreenState();
}

class _AddMasterScreenState extends State<AddMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createMaster() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // 1. Создаём пользователя через обычный signUp
      // Триггер автоматически создаст запись в public.users с role_id = 1
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _nameController.text.trim()}, // ✅ Исправлено: data как именованный параметр
      );

      final newUserId = authResponse.user?.id;
      if (newUserId == null) throw Exception('Не удалось создать пользователя');

      // 2. Обновляем роль на "Мастер" (2) и добавляем телефон
      await Supabase.instance.client
          .from('users')
          .update({
            'role_id': 2,
            'phone': _phoneController.text.trim().isNotEmpty 
                ? _phoneController.text.trim() 
                : null,
          })
          .eq('user_id', newUserId);

      // 3. Выходим из сессии нового пользователя (админ останется в системе)
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Мастер успешно добавлен'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      debugPrint('❌ Auth ошибка: ${e.message}');
      
      String message = 'Ошибка: ${e.message}';
      if (e.message.contains('User already registered')) {
        message = 'Пользователь с таким email уже существует';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('❌ Ошибка создания мастера: $e');
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('42501')) {
          errorMsg = 'Ошибка прав доступа. Выполните SQL-скрипт для обновления RLS.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $errorMsg'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Новый мастер',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                controller: _nameController,
                label: 'ФИО мастера',
                icon: Icons.person,
                validator: (v) => v?.isEmpty ?? true ? 'Введите имя' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Email для входа',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Введите email';
                  if (!v!.contains('@')) return 'Некорректный email';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Телефон (необязательно)',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: 'Пароль',
                icon: Icons.lock,
                obscureText: true,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Введите пароль';
                  if (v!.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                '• Минимум 6 символов',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createMaster,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Создать мастера',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: const Color(0xFF444444),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD47926), width: 2),
        ),
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      ),
      validator: validator,
    );
  }
}