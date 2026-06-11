import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import 'add_edit_master_screen.dart';

class ManageMastersScreen extends StatefulWidget {
  const ManageMastersScreen({super.key});

  @override
  State<ManageMastersScreen> createState() => _ManageMastersScreenState();
}

class _ManageMastersScreenState extends State<ManageMastersScreen> {
  List<Map<String, dynamic>> _masters = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredMasters = [];

  @override
  void initState() {
    super.initState();
    _loadMasters();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _updateFilteredMasters();
    });
  }

  void _updateFilteredMasters() {
    _filteredMasters = _masters.where((m) {
      if (_searchQuery.isEmpty) return true;
      final name = (m['full_name'] ?? '').toLowerCase();
      final email = (m['email'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();
  }

  Future<void> _loadMasters() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, created_at, master_rank')
          .eq('role_id', 2)
          .order('created_at', ascending: false)
          .range(0, 99);

      if (mounted) {
        setState(() {
          _masters = List<Map<String, dynamic>>.from(response);
          _updateFilteredMasters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки мастеров: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editMaster(Map<String, dynamic> master) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEditMasterScreen(existingMaster: master)),
    );
    if (result == true && mounted) _loadMasters();
  }

  Future<void> _deleteMaster(String masterId, String masterName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF444444),
        title: const Text('Удалить мастера?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Вы уверены, что хотите навсегда удалить мастера "$masterName"? Это действие нельзя отменить.',
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
      await Supabase.instance.client.from('users').delete().eq('user_id', masterId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Мастер удален'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMasters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления (возможно, есть связанные записи): $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMaster() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditMasterScreen()),
    );
    if (result == true && mounted) _loadMasters();
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
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Поиск мастера...',
                  hintStyle: TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.search, color: Colors.white54),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addMaster,
                icon: const Icon(Icons.add),
                label: const Text('Добавить мастера'),
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
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredMasters.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'Нет мастеров' : 'Мастера не найдены',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredMasters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final master = _filteredMasters[index];
                          return _MasterCard(
                            master: master,
                            onEdit: _editMaster,
                            onDelete: _deleteMaster,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  final Map<String, dynamic> master;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String, String) onDelete;

  const _MasterCard({
    required this.master,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = master['full_name'] ?? 'Без имени';
    final masterId = master['user_id'];
    final photoUrl = master['photo_url'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Аватар
          photoUrl != null && photoUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitialsAvatar(name),
                  ),
                )
              : _buildInitialsAvatar(name),
          const SizedBox(width: 12),

          // Информация
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
                if (master['master_rank'] != null)
                  Text(
                    master['master_rank'],
                    style: const TextStyle(
                      color: Color(0xFFD47926),
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  master['email'] ?? '',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),

          // Кнопки действий
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
            onPressed: () => onEdit(master),
            tooltip: 'Редактировать',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => onDelete(masterId, name),
            tooltip: 'Удалить',
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFF555555),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}