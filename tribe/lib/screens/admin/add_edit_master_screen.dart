import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

class AddEditMasterScreen extends StatefulWidget {
  final Map<String, dynamic>? master;

  const AddEditMasterScreen({super.key, this.master});

  @override
  State<AddEditMasterScreen> createState() => _AddEditMasterScreenState();
}

class _AddEditMasterScreenState extends State<AddEditMasterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String? _selectedRank;
  bool _isSaving = false;
  bool get _isEditing => widget.master != null;

  static const List<String> _validRanks = [
    'Основатель',
    'Старший мастер',
    'Топ мастер',
    'Мастер маникюра',
    'Эксперт',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _emailController.text = widget.master!['email'] ?? '';
      _fullNameController.text = widget.master!['full_name'] ?? '';
      _phoneController.text = widget.master!['phone'] ?? '';
      _selectedRank = widget.master!['master_rank'];
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveMaster() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (_isEditing) {
        await _updateMaster();
      } else {
        await _createMaster();
      }
    } catch (e) {
      ErrorHandler.logError('AddEditMasterScreen._saveMaster', e);
      if (mounted) {
        _showErrorDialog(_getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ✅ Создание нового мастера через SQL функцию
  Future<void> _createMaster() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final validRank = _validateRank(_selectedRank);

    if (password.length < 6) {
      _showErrorDialog('Пароль должен содержать минимум 6 символов');
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      _showErrorDialog('Введите корректный email');
      return;
    }

    debugPrint('👤 Creating master:');
    debugPrint('   email: $email');
    debugPrint('   full_name: $fullName');
    debugPrint('   master_rank: $validRank');

    // ✅ Вызываем SQL функцию вместо auth.admin.createUser
    final result = await Supabase.instance.client.rpc(
      'create_master',
      params: {
        'p_email': email,
        'p_password': password,
        'p_full_name': fullName,
        'p_phone': phone.isNotEmpty ? phone : null,
        'p_photo_url': null, // ✅ URL фото убран
        'p_master_rank': validRank,
        'p_role_id': 2, // role_id = 2 для мастера
      },
    ).timeout(const Duration(seconds: 30));

    debugPrint('✅ Master created: $result');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Мастер успешно добавлен'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  Future<void> _updateMaster() async {
    final userId = widget.master!['user_id'];
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final validRank = _validateRank(_selectedRank);

    await Supabase.instance.client.from('users').update({
      'full_name': fullName,
      'phone': phone.isNotEmpty ? phone : null,
      'master_rank': validRank,
    }).eq('user_id', userId);

    final newPassword = _passwordController.text.trim();
    if (newPassword.isNotEmpty) {
      if (newPassword.length < 6) {
        throw Exception('Пароль должен содержать минимум 6 символов');
      }
      await Supabase.instance.client.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Данные мастера обновлены'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  String? _validateRank(String? rank) {
    if (rank == null || rank.isEmpty) return null;
    if (_validRanks.contains(rank)) return rank;
    return null;
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (error is AuthApiException) {
      if (errorStr.contains('user_already_exists') || 
          errorStr.contains('already registered') ||
          error.statusCode == '422') {
        return '❌ Пользователь с таким email уже зарегистрирован.\n\nИспользуйте другой email.';
      }
      if (errorStr.contains('not_admin') || errorStr.contains('403')) {
        return '❌ Недостаточно прав.\n\nВаш аккаунт должен иметь роль администратора (role_id = 3).';
      }
      if (errorStr.contains('invalid email')) {
        return '❌ Некорректный email адрес';
      }
    }
    
    if (error is PostgrestException) {
      if (errorStr.contains('check constraint') || errorStr.contains('master_rank')) {
        return '❌ Недопустимое значение ранга мастера.';
      }
      if (errorStr.contains('duplicate') || errorStr.contains('unique')) {
        return '❌ Пользователь с таким email уже существует';
      }
      if (errorStr.contains('function') || errorStr.contains('does not exist')) {
        return '❌ Функция create_master не найдена.\n\nВыполните SQL скрипт в Supabase.';
      }
    }
    
    if (errorStr.contains('socket') || errorStr.contains('connection')) {
      return '❌ Нет подключения к интернету';
    }
    if (errorStr.contains('timeout')) {
      return '❌ Превышено время ожидания';
    }
    
    return '❌ Ошибка: $error';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Ошибка', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(color: Colors.white70)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Редактировать мастера' : 'Добавить мастера',
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
                _isEditing ? 'Редактирование' : 'Новый мастер',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'example@mail.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isEditing,
                validator: (value) {
                  if (_isEditing) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите email';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Некорректный email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _passwordController,
                label: _isEditing ? 'Новый пароль (оставьте пустым если не менять)' : 'Пароль',
                hint: 'Минимум 6 символов',
                obscureText: true,
                validator: (value) {
                  if (_isEditing) {
                    if (value != null && value.isNotEmpty && value.length < 6) {
                      return 'Минимум 6 символов';
                    }
                    return null;
                  }
                  if (value == null || value.isEmpty) {
                    return 'Введите пароль';
                  }
                  if (value.length < 6) {
                    return 'Минимум 6 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _fullNameController,
                label: 'ФИО',
                hint: 'Иванов Иван Иванович',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите ФИО';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _phoneController,
                label: 'Телефон',
                hint: '+7 (999) 123-45-67',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),

              const Text(
                'Ранг мастера',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF444444),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedRank,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF444444),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    hint: const Text(
                      'Не выбрано',
                      style: TextStyle(color: Colors.white54),
                    ),
                    items: _validRanks.map((rank) {
                      return DropdownMenuItem(
                        value: rank,
                        child: Text(rank),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRank = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveMaster,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Сохранить изменения' : 'Добавить мастера',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white54,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
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
              borderSide: const BorderSide(
                color: Color(0xFFD47926),
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}