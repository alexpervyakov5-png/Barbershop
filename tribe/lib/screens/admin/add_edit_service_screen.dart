import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/error_handler.dart';

class AddEditServiceScreen extends StatefulWidget {
  final Map<String, dynamic>? existingService;

  const AddEditServiceScreen({super.key, this.existingService});

  @override
  State<AddEditServiceScreen> createState() => _AddEditServiceScreenState();
}

class _AddEditServiceScreenState extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  bool get isEditing => widget.existingService != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.existingService!['name'] ?? '';
      _descriptionController.text = widget.existingService!['description'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ ИСПРАВЛЕНО: Явно указываем тип Map<String, dynamic>
      final Map<String, dynamic> serviceData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
      };

      if (isEditing) {
        await Supabase.instance.client
            .from('services')
            .update(serviceData)
            .eq('service_id', widget.existingService!['service_id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Услуга обновлена'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        serviceData['is_active'] = true;
        await Supabase.instance.client.from('services').insert(serviceData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Услуга добавлена'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      ErrorHandler.logError('AddEditServiceScreen._saveService', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: isEditing
              ? 'Не удалось обновить услугу'
              : 'Не удалось создать услугу',
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF363636),
        title: Text(
          isEditing ? 'Редактировать услугу' : 'Новая услуга',
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
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Название услуги',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.cut, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF444444),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Введите название' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Описание (необязательно)',
                  labelStyle: TextStyle(color: Colors.white54),
                  prefixIcon: const Icon(Icons.description, color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF444444),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveService,
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
                          isEditing ? 'Сохранить изменения' : 'Создать услугу',
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
}