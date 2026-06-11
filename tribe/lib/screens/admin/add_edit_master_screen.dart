import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

class AddEditMasterScreen extends StatefulWidget {
  final Map<String, dynamic>? master; // null = создание нового

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
  final _photoUrlController = TextEditingController();
  
  String? _selectedRank;
  bool _isSaving = false;
  bool get _isEditing => widget.master != null;

  // ✅ Допустимые значения master_rank (должны совпадать с БД)
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
      _photoUrlController.text = widget.master!['photo_url'] ?? '';
      _selectedRank = widget.master!['master_rank'];
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _photoUrlController.dispose();
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

  // ✅ Создание нового мастера
  Future<void> _createMaster() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final photoUrl = _photoUrlController.text.trim();

    // ✅ Валидация пароля
    if (password.length < 6) {
      _showErrorDialog('Пароль должен содержать минимум 6 символов');
      return;
    }

    // ✅ Валидация email
    if (!email.contains('@') || !email.contains('.')) {
      _showErrorDialog('Введите корректный email');
      return;
    }

    // ✅ Валидация master_rank - должно быть null или из списка
    final String? validRank = _validateRank(_selectedRank);

    debugPrint('👤 Creating master:');
    debugPrint('   email: $email');
    debugPrint('   full_name: $fullName');
    debugPrint('   master_rank: $validRank');

    // ✅ ШАГ 1: Создаём пользователя в Supabase Auth
    final authResponse = await Supabase.instance.client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: password,
        emailConfirm: true,
        userMetadata: {
          'full_name': fullName,
          'role': 'master',
        },
      ),
    );

    final userId = authResponse.user?.id;
    if (userId == null) {
      throw Exception('Не удалось создать пользователя');
    }

    debugPrint('✅ User created in Auth: $userId');

    // ✅ ШАГ 2: Создаём запись в таблице users
    try {
      await Supabase.instance.client.from('users').insert({
        'user_id': userId,
        'email': email,
        'full_name': fullName,
        'phone': phone.isNotEmpty ? phone : null,
        'photo_url': photoUrl.isNotEmpty ? photoUrl : null,
        'master_rank': validRank, // ✅ null или валидное значение
        'role_id': 2, // role_id = 2 для мастера (проверьте в вашей БД!)
        'is_active': true,
      });

      debugPrint('✅ User created in users table');
    } catch (e) {
      // ✅ Если запись в users не удалась - удаляем пользователя из Auth
      debugPrint('❌ Failed to create user in users table: $e');
      try {
        await Supabase.instance.client.auth.admin.deleteUser(userId);
        debugPrint('🗑️ Rolled back Auth user');
      } catch (rollbackError) {
        debugPrint('⚠️ Failed to rollback Auth user: $rollbackError');
      }
      rethrow;
    }

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

  // ✅ Обновление существующего мастера
  Future<void> _updateMaster() async {
    final userId = widget.master!['user_id'];
    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final photoUrl = _photoUrlController.text.trim();
    final validRank = _validateRank(_selectedRank);

    await Supabase.instance.client.from('users').update({
      'full_name': fullName,
      'phone': phone.isNotEmpty ? phone : null,
      'photo_url': photoUrl.isNotEmpty ? photoUrl : null,
      'master_rank': validRank,
    }).eq('user_id', userId);

    // ✅ Если изменился пароль - обновляем в Auth
    final newPassword = _passwordController.text.trim();
    if (newPassword.isNotEmpty) {
      if (newPassword.length < 6) {
        throw Exception('Пароль должен содержать минимум 6 символов');
      }
      // ✅ ИСПРАВЛЕНО: добавлен именованный параметр 'attributes'
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

  // ✅ Валидация master_rank
  String? _validateRank(String? rank) {
    if (rank == null || rank.isEmpty) return null;
    if (_validRanks.contains(rank)) return rank;
    debugPrint('⚠️ Invalid rank: $rank. Using null.');
    return null;
  }

  // ✅ Понятные сообщения об ошибках
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    // Ошибки Auth
    if (error is AuthApiException) {
      if (errorStr.contains('user_already_exists') || 
          errorStr.contains('already registered') ||
          // ✅ ИСПРАВЛЕНО: statusCode это String, сравниваем со строкой
          error.statusCode == '422') {
        return '❌ Пользователь с таким email уже зарегистрирован.\n\nИспользуйте другой email или войдите в систему.';
      }
      if (errorStr.contains('invalid email')) {
        return '❌ Некорректный email адрес';
      }
      if (errorStr.contains('weak password')) {
        return '❌ Слишком простой пароль. Используйте минимум 6 символов.';
      }
      if (errorStr.contains('permission') || errorStr.contains('403')) {
        return '❌ Недостаточно прав. Требуется роль администратора.';
      }
    }
    
    // Ошибки БД
    if (error is PostgrestException) {
      if (errorStr.contains('check constraint') || errorStr.contains('master_rank')) {
        return '❌ Недопустимое значение ранга мастера.\n\nДопустимые значения: Основатель, Старший мастер, Топ мастер, Мастер маникюра, Эксперт';
      }
      if (errorStr.contains('duplicate') || errorStr.contains('unique')) {
        return '❌ Запись с такими данными уже существует';
      }
      if (errorStr.contains('foreign key')) {
        return '❌ Ошибка связи с другой таблицей. Проверьте role_id.';
      }
    }
    
    // Сетевые ошибки
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
      // ✅ ИСПРАВЛЕНО: используем обычный AppBar вместо TribeAppBar с title
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

              // Email
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'example@mail.com',
                keyboardType: TextInputType.emailAddress,
                enabled: !_isEditing, // При редактировании email нельзя менять
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

              // Пароль
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

              // ФИО
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

              // Телефон
              _buildTextField(
                controller: _phoneController,
                label: 'Телефон',
                hint: '+7 (999) 123-45-67',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // URL фото
              _buildTextField(
                controller: _photoUrlController,
                label: 'URL фото (необязательно)',
                hint: 'https://...',
              ),
              const SizedBox(height: 16),

              // Ранг мастера
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

              // Кнопка сохранения
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