import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import '../../utils/error_handler.dart';
import 'add_edit_service_screen.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('services')
          .select('service_id, name, description, created_at')
          .order('name', ascending: true)
          .range(0, 99);

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      ErrorHandler.logError('ManageServicesScreen._loadServices', e);
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось загрузить услуги',
        );
      }
    }
  }

  Future<void> _editService(Map<String, dynamic> service) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditServiceScreen(existingService: service)),
    );
    if (result == true && mounted) _loadServices();
  }

  Future<void> _deleteService(int serviceId, String serviceName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Удалить услугу?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Вы уверены, что хотите навсегда удалить услугу "$serviceName"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('services')
          .delete()
          .eq('service_id', serviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Услуга удалена'),
            backgroundColor: Colors.green,
          ),
        );
        _loadServices();
      }
    } catch (e) {
      ErrorHandler.logError('ManageServicesScreen._deleteService', e);
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          e,
          customMessage: 'Не удалось удалить. Возможно, услуга привязана к мастерам или записям.',
        );
      }
    }
  }

  Future<void> _addService() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditServiceScreen()),
    );
    if (result == true && mounted) _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF363636),
      appBar: const TribeAppBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addService,
                icon: const Icon(Icons.add),
                label: const Text('Добавить услугу'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD47926),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _services.isEmpty
                    ? const Center(
                        child: Text('Нет услуг', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _services.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = _services[index];
                          return _ServiceCard(
                            service: service,
                            onEdit: _editService,
                            onDelete: _deleteService,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Map<String, dynamic> service;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(int, String) onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final serviceId = service['service_id'] as int;
    final name = service['name'];
    final description = service['description'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (description != null && description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      description,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Кнопки действий
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => onEdit(service),
            tooltip: 'Редактировать',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => onDelete(serviceId, name),
            tooltip: 'Удалить',
          ),
        ],
      ),
    );
  }
}