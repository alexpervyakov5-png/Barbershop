import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';
import '../../utils/yandex_storage_service.dart';

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
  bool _isLoading = false;
  bool _isUploadingAvatar = false;

  File? _avatarFile;
  String? _avatarUrl;

  String? _selectedRank;

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
    _avatarUrl = widget.currentMaster['photo_url'];
    _selectedRank = widget.currentMaster['master_rank'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ✅ Выбор фото (без обрезки - обрезка будет визуальной через ClipOval)
  Future<void> _pickAvatar() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF363636),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Изменить фото',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFD47926)),
                title: const Text('Из галереи', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFD47926)),
                title: const Text('Сделать фото', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              if (_avatarUrl != null || _avatarFile != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Удалить фото', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    setState(() {
                      _avatarFile = null;
                      _avatarUrl = null;
                    });
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );

      if (source == null) return;

      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _avatarFile = File(pickedFile.path);
      });

      debugPrint('✅ Avatar selected: ${_avatarFile!.path}');
    } catch (e) {
      ErrorHandler.logError('EditMasterProfileScreen._pickAvatar', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось выбрать фото',
        );
      }
    }
  }

  Future<String?> _uploadAvatar() async {
    if (_avatarFile == null) return _avatarUrl;

    setState(() => _isUploadingAvatar = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Пользователь не авторизован');

      final fileName = 'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final url = await YandexStorageService().uploadFile(
        file: _avatarFile!,
        fileName: fileName,
      );

      debugPrint('✅ Avatar uploaded: $url');
      return url;
    } catch (e) {
      ErrorHandler.logError('EditMasterProfileScreen._uploadAvatar', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось загрузить фото',
        );
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Пользователь не авторизован');

      String? newAvatarUrl = _avatarUrl;

      if (_avatarFile != null) {
        newAvatarUrl = await _uploadAvatar();
        if (newAvatarUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final String? validRank = (_selectedRank != null &&
              _selectedRank!.isNotEmpty &&
              _rankOptions.contains(_selectedRank))
          ? _selectedRank
          : null;

      final updateData = {
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'master_rank': validRank,
        'photo_url': newAvatarUrl,
      };

      await Supabase.instance.client
          .from('users')
          .update(updateData)
          .eq('user_id', userId);

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

  Widget _buildAvatar() {
    final bool hasImage = _avatarFile != null ||
        (_avatarUrl != null && _avatarUrl!.toString().isNotEmpty);

    return Stack(
      children: [
        GestureDetector(
          onTap: _isUploadingAvatar ? null : _pickAvatar,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF555555),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD47926),
                width: 2,
              ),
            ),
            child: _isUploadingAvatar
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD47926),
                      strokeWidth: 2,
                    ),
                  )
                : _avatarFile != null
                    ? ClipOval(
                        child: Image.file(
                          _avatarFile!,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        ),
                      )
                    : hasImage
                        ? ClipOval(
                            child: Image.network(
                              _avatarUrl!,
                              fit: BoxFit.cover,
                              width: 120,
                              height: 120,
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
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFD47926),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
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

              Center(child: _buildAvatar()),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _isUploadingAvatar
                      ? 'Загрузка фото...'
                      : 'Нажмите, чтобы изменить фото',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 32),

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

              DropdownButtonFormField<String>(
                initialValue: _selectedRank != null && _rankOptions.contains(_selectedRank)
                    ? _selectedRank
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
                  setState(() {
                    _selectedRank = value;
                  });
                },
              ),
              const SizedBox(height: 16),

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

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_isLoading || _isUploadingAvatar) ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD47926),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: (_isLoading || _isUploadingAvatar)
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

              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: (_isLoading || _isUploadingAvatar) ? null : () => Navigator.pop(context),
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