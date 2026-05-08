import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

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
      // ✅ ВЫЗОВ signUp С ПРАВИЛЬНЫМИ ИМЕНОВАННЫМИ ПАРАМЕТРАМИ
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _nameController.text.trim()},
      );

      final newUserId = authResponse.user?.id;
      if (newUserId == null) throw Exception('Не удалось создать пользователя');

      await Supabase.instance.client
          .from('users')
          .update({
            'role_id': 2,
            'phone': _phoneController.text.trim().isNotEmpty 
                ? _phoneController.text.trim() 
                : null,
          })
          .eq('user_id', newUserId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Мастер успешно создан'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ErrorHandler.logError('AddMasterScreen._createMaster', e);
      
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: _getCustomErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getCustomErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('user already registered')) {
      return '👤 Пользователь с таким email уже существует';
    }
    if (errorStr.contains('invalid email')) {
      return '📧 Некорректный email адрес';
    }
    if (errorStr.contains('weak password')) {
      return '🔒 Пароль слишком слабый';
    }
    if (errorStr.contains('connection') || errorStr.contains('network')) {
      return '📡 Ошибка подключения к интернету';
    }
    
    return null;
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
                'Пригласить мастера',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Мастер получит доступ сразу после создания',
                style: TextStyle(color: Colors.white54, fontSize: 14),
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
                label: 'Email мастера',
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
                label: 'Пароль для входа',
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