import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';

class EditMasterProfileScreen extends StatefulWidget {
  final Map<String, dynamic> currentMaster;

  const EditMasterProfileScreen({
    super.key,
    required this.currentMaster,
  });

  @override
  State<EditMasterProfileScreen> createState() => _EditMasterProfileScreenState();
}

class _EditMasterProfileScreenState extends State<EditMasterProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _rankController;
  bool _isLoading = false;

  static const _rankOptions = [
    'Основатель',
    'Старший мастер',
    'Топ мастер',
    'Мастер маникюра',
    'Эксперт',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.currentMaster['full_name'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.currentMaster['phone'] ?? '',
    );
    _rankController = TextEditingController(
      text: widget.currentMaster['master_rank'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rankController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Пользователь не авторизован');

      final updateData = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'master_rank': _rankController.text.trim().isNotEmpty
            ? _rankController.text.trim()
            : null,
      };

      await Supabase.instance.client
          .from('users')
          .update(updateData)
          .eq('user_id', userId);

      // Обновляем метаданные в auth.users
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {'full_name': _nameController.text.trim()},
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Профиль обновлён'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ErrorHandler.logError('EditMasterProfileScreen._saveProfile', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось сохранить изменения',
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
      appBar: const TribeAppBar(showProfileIcon: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Редактирование профиля',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Измените ваши данные',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Аватар
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: Color(0xFF555555),
                    shape: BoxShape.circle,
                  ),
                  child: widget.currentMaster['photo_url'] != null &&
                          widget.currentMaster['photo_url'].toString().isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            widget.currentMaster['photo_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 48,
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Имя
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Имя *',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.person_outline, color: Colors.white54),
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
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Введите имя';
                  }
                  if (value.trim().length < 2) {
                    return 'Имя должно содержать минимум 2 символа';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Должность
              DropdownButtonFormField<String>(
                initialValue: _rankOptions.contains(_rankController.text)
                    ? _rankController.text
                    : null,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Должность',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.workspace_premium, color: Colors.white54),
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
                ),
                dropdownColor: const Color(0xFF444444),
                items: _rankOptions.map((rank) {
                  return DropdownMenuItem(
                    value: rank,
                    child: Text(rank, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _rankController.text = value;
                  }
                },
              ),
              const SizedBox(height: 16),

              // Email (только для просмотра)
              TextFormField(
                initialValue: widget.currentMaster['email'] ?? '',
                style: const TextStyle(color: Colors.white54),
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF3A3A3A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Email нельзя изменить',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Телефон
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Телефон (необязательно)',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.phone_outlined, color: Colors.white54),
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
                ),
              ),
              const SizedBox(height: 40),

              // Кнопка "Сохранить"
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
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
                          'Сохранить изменения',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Кнопка "Отмена"
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Отмена',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}