import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/tribe_app_bar.dart';
import 'add_master_screen.dart';

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
    setState(() => _searchQuery = _searchController.text.toLowerCase());
  }

  Future<void> _loadMasters() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('user_id, full_name, email, phone, photo_url, is_active, created_at, raiting_avg')
          .eq('role_id', 2)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _masters = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Ошибка загрузки мастеров: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMasterStatus(String masterId, bool isActive) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'is_active': isActive})
          .eq('user_id', masterId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isActive ? 'Мастер активирован' : 'Мастер заблокирован'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
          ),
        );
        _loadMasters();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMaster() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMasterScreen()),
    );
    if (result == true && mounted) _loadMasters();
  }

  @override
  Widget build(BuildContext context) {
    final filteredMasters = _masters.where((m) {
      if (_searchQuery.isEmpty) return true;
      final name = (m['full_name'] ?? '').toLowerCase();
      final email = (m['email'] ?? '').toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

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
                : filteredMasters.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'Нет мастеров' : 'Мастера не найдены',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: filteredMasters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final master = filteredMasters[index];
                          return _MasterCard(
                            masterId: master['user_id'],
                            name: master['full_name'] ?? 'Без имени',
                            email: master['email'],
                            phone: master['phone'],
                            photoUrl: master['photo_url'],
                            isActive: master['is_active'] ?? true,
                            onToggleStatus: _toggleMasterStatus,
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
  final String masterId;
  final String name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final bool isActive;
  final void Function(String, bool) onToggleStatus;

  const _MasterCard({
    required this.masterId,
    required this.name,
    this.email,
    this.phone,
    this.photoUrl,
    required this.isActive,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF444444),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.transparent : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          photoUrl != null && photoUrl!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildInitialsAvatar(),
                  ),
                )
              : _buildInitialsAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Заблокирован',
                          style: TextStyle(color: Colors.red, fontSize: 11),
                        ),
                      ),
                  ],
                ),
                if (email != null)
                  Text(email!, style: TextStyle(color: Colors.white54, fontSize: 13)),
                if (phone != null)
                  Text(phone!, style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: isActive,
            onChanged: (value) => onToggleStatus(masterId, value),
            activeColor: const Color(0xFFD47926),
            activeTrackColor: const Color(0xFFD47926).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
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
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}