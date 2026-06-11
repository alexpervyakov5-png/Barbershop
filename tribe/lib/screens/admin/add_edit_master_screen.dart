import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/error_handler.dart';

class AddEditMasterScreen extends StatefulWidget {
  final Map<String, dynamic>? existingMaster;

  const AddEditMasterScreen({super.key, this.existingMaster});

  @override
  State<AddEditMasterScreen> createState() => _AddEditMasterScreenState();
}

class _AddEditMasterScreenState extends State<AddEditMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rankController = TextEditingController();
  bool _isLoading = false;

  bool get isEditing => widget.existingMaster != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existingMaster!['full_name'] ?? '';
      _emailController.text = widget.existingMaster!['email'] ?? '';
      _phoneController.text = widget.existingMaster!['phone'] ?? '';
      _rankController.text = widget.existingMaster!['master_rank'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  Future<void> _saveMaster() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (isEditing) {
        // ✅ РЕДАКТИРОВАНИЕ: Обновляем данные в таблице users
        await Supabase.instance.client.from('users').update({
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'master_rank': _rankController.text.trim().isNotEmpty
              ? _rankController.text.trim()
              : null,
        }).eq('user_id', widget.existingMaster!['user_id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Данные мастера обновлены'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        // ✅ СОЗДАНИЕ: Регистрируем через Supabase Auth
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'full_name': _nameController.text.trim()},
        );

        final newUserId = authResponse.user?.id;
        if (newUserId == null) throw Exception('Не удалось создать пользователя');

        await Supabase.instance.client.from('users').insert({
          'user_id': newUserId,
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'role_id': 2,
          'master_rank': _rankController.text.trim().isNotEmpty
              ? _rankController.text.trim()
              : null,
          'is_active': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Мастер успешно создан'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      ErrorHandler.logError('AddEditMasterScreen._saveMaster', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: isEditing
              ? 'Не удалось обновить данные'
              : 'Не удалось создать мастера',
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
      // ✅ ИСПРАВЛЕНО: Убран дублирующийся appBar, оставлен только один
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        title: Text(
          isEditing ? 'Редактировать мастера' : 'Пригласить мастера',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing
                    ? 'Измените данные мастера'
                    : 'Мастер получит доступ сразу после создания',
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
                controller: _rankController,
                label: 'Должность (например: Топ-мастер)',
                icon: Icons.workspace_premium,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _emailController,
                label: 'Email мастера',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                enabled: !isEditing,
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

              if (!isEditing) ...[
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
                const SizedBox(height: 24),
              ],

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMaster,
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
                      : Text(
                          isEditing ? 'Сохранить изменения' : 'Создать мастера',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
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
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: enabled ? Colors.white54 : Colors.white24,
        ),
        prefixIcon: Icon(
          icon,
          color: enabled ? Colors.white54 : Colors.white24,
        ),
        filled: true,
        fillColor: enabled ? const Color(0xFF444444) : const Color(0xFF3A3A3A),
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