import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tribe_app_bar.dart';
import 'master_list_screen.dart';
import 'appointment_time_screen.dart';

class ServiceScreen extends StatefulWidget {
  final String? barberId;
  final String? masterName;

  const ServiceScreen({
    super.key,
    this.barberId,
    this.masterName,
  });

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final Set<int> _selectedServiceIds = {};
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _filteredServices = [];
  final Map<int, Map<String, dynamic>> _serviceDetails = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _searchController.addListener(_filterServices);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      List<Map<String, dynamic>> services = [];
      
      if (widget.barberId != null) {
        final bsResponse = await Supabase.instance.client
            .from('barber_services')
            .select('service_id, price, duration_min')
            .eq('barber_id', widget.barberId!)
            .timeout(const Duration(seconds: 10));

        final List<dynamic> bsList = bsResponse as List<dynamic>;
        
        final Map<int, Map<String, dynamic>> details = {};
        for (var item in bsList) {
          final serviceId = item['service_id'] as int;
          details[serviceId] = {
            'price': item['price'],
            'duration_min': (item['duration_min'] as num?)?.toInt() ?? 60,
          };
        }
        _serviceDetails.addAll(details);

        final List<int> ids = bsList.map((e) => e['service_id'] as int).toList();

        if (ids.isEmpty) {
          if (mounted) setState(() { _allServices = []; _isLoading = false; });
          return;
        }

        final List<Object> idsObj = ids.cast<Object>();
        
        final sResponse = await Supabase.instance.client
            .from('services')
            .select('service_id, name, description')
            .inFilter('service_id', idsObj)
            .eq('is_active', true)
            .order('name', ascending: true)
            .timeout(const Duration(seconds: 10));
        
        services = List<Map<String, dynamic>>.from(sResponse as List);
      } else {
        final sResponse = await Supabase.instance.client
            .from('services')
            .select('service_id, name, description')
            .eq('is_active', true)
            .order('name', ascending: true)
            .timeout(const Duration(seconds: 10));
        services = List<Map<String, dynamic>>.from(sResponse as List);
      }

      if (!mounted) return;
      setState(() {
        _allServices = services;
        _filteredServices = services;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Ошибка загрузки услуг: $e');
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      String errorMessage = 'Не удалось загрузить услуги';
      
      if (e.toString().contains('Connection reset')) {
        errorMessage = 'Проблема с подключением. Проверьте интернет.';
      } else if (e.toString().contains('timeout')) {
        errorMessage = 'Превышено время ожидания. Попробуйте снова.';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _filterServices() {
    if (!mounted) return;
    final query = _searchController.text.toLowerCase().trim();
    
    setState(() {
      _filteredServices = query.isEmpty
          ? _allServices
          : _allServices.where((s) {
              final name = (s['name'] ?? '').toLowerCase();
              final desc = (s['description'] ?? '').toLowerCase();
              return name.contains(query) || desc.contains(query);
            }).toList();
    });
  }

  void _toggleService(int serviceId) {
    if (!mounted) return;
    setState(() {
      if (_selectedServiceIds.contains(serviceId)) {
        _selectedServiceIds.remove(serviceId);
      } else {
        _selectedServiceIds.add(serviceId);
      }
    });
  }

  void _clearSearch() {
    if (!mounted) return;
    _searchController.clear();
  }

  int _calculateTotalDuration() {
    int total = 0;
    for (var id in _selectedServiceIds) {
      if (widget.barberId != null) {
        final duration = _serviceDetails[id]?['duration_min'];
        if (duration is int) {
          total += duration;
        } else if (duration is num) {
          total += duration.toInt();
        } else {
          total += 60;
        }
      } else {
        total += 60;
      }
    }
    return total;
  }

  void _proceed() {
    if (!mounted) return;
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одну услугу'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.barberId != null) {
      final totalDuration = _calculateTotalDuration();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentTimeScreen(
            masterId: widget.barberId!,
            masterName: widget.masterName ?? 'Мастер',
            serviceIds: _selectedServiceIds.toList(),
            totalDuration: totalDuration,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MasterListScreen(serviceIds: _selectedServiceIds.toList()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMasterMode = widget.barberId != null;
    final totalDuration = _calculateTotalDuration();

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
                borderRadius: BorderRadius.circular(4),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Поиск услуг...',
                  hintStyle: const TextStyle(color: Colors.white54, fontSize: 15),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 22),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                          onPressed: _clearSearch,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),

          if (_searchController.text.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Найдено: ${_filteredServices.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _filteredServices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.white24),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.trim().isEmpty
                                  ? (isMasterMode ? 'У мастера нет услуг' : 'Нет доступных услуг')
                                  : 'Услуги не найдены',
                              style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _filteredServices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final service = _filteredServices[index];
                          final serviceId = service['service_id'] as int;
                          final isSelected = _selectedServiceIds.contains(serviceId);
                          
                          String? priceText;
                          String? durationText;
                          
                          if (isMasterMode && _serviceDetails.containsKey(serviceId)) {
                            final details = _serviceDetails[serviceId]!;
                            final price = details['price'];
                            final duration = details['duration_min'];
                            
                            if (price != null) {
                              if (price is num) {
                                priceText = '${price.toInt()} ₽';
                              } else {
                                priceText = '$price ₽';
                              }
                            }
                            if (duration != null) {
                              durationText = '$duration мин';
                            }
                          }

                          return _ServiceCard(
                            serviceId: serviceId,
                            name: service['name'],
                            description: service['description'],
                            price: priceText,
                            duration: durationText,
                            isSelected: isSelected,
                            onToggle: _toggleService,
                          );
                        },
                      ),
          ),

          if (_selectedServiceIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              color: const Color(0xFF363636),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _proceed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF363636),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    elevation: 0,
                  ),
                  child: Text(
                    isMasterMode 
                        ? 'Записаться на $totalDuration мин'
                        : 'Выбрать мастера (${_selectedServiceIds.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final int serviceId;
  final String name;
  final String? description;
  final String? price;
  final String? duration;
  final bool isSelected;
  final void Function(int) onToggle;

  const _ServiceCard({
    required this.serviceId,
    required this.name,
    required this.description,
    this.price,
    this.duration,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(serviceId),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF505050) : const Color(0xFF444444),
          borderRadius: BorderRadius.circular(4),
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
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (description != null && description!.isNotEmpty)
                    Text(
                      description!,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (price != null || duration != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (price != null)
                          Text(
                            price!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (price != null && duration != null)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('•', style: TextStyle(color: Colors.white38)),
                          ),
                        if (duration != null)
                          Text(
                            duration!,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFD4AF37),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}