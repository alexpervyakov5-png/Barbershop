// lib/screens/place_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/tribe_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

class PlaceScreen extends StatelessWidget {
  const PlaceScreen({super.key});

  // Координаты: Никитская улица, 171, Киров
  static const LatLng _barberShopLocation = LatLng(58.590750, 49.672588);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TribeAppBar(),
      body: Column(
        children: [
          // Карта
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _barberShopLocation,
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.tribe',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _barberShopLocation,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Информация о барбершопе
          Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF444444),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tribe Barbershop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.location_on, 'Никитская улица, 171, Киров'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.phone, '+7 (922) 933-92-23'),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.access_time, 'Ежедневно: 10:00 - 20:00'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Открыть в навигаторе
                      _openInMaps(context);
                    },
                    icon: const Icon(Icons.navigation, color: Color(0xFF363636)),
                    label: const Text(
                      'Построить маршрут',
                      style: TextStyle(color: Color(0xFF363636)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ],
    );
  }

  void _openInMaps(BuildContext context) async {
    final latitude = 58.590655;
    final longitude = 49.672628;
    final address = 'Никитская+улица,+171,+Киров';
    
    // Попытка открыть в Яндекс Картах (предпочтительно для РФ)
    final yandexUri = Uri.parse(
      'yandexmaps://maps.yandex.ru/?pt=$longitude,$latitude&z=16&l=map&pp_text=Tribe+Barbershop'
    );
    
    // Fallback на универсальную geo: ссылку
    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$address');
    
    if (await canLaunchUrl(yandexUri)) {
      await launchUrl(yandexUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
    } else {
      // Открываем в браузере
      final webUri = Uri.parse(
        'https://yandex.ru/maps/?pt=$longitude,$latitude&z=16&l=map'
      );
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }
}