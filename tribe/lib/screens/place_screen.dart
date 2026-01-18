// lib/screens/place_screen.dart
import 'package:flutter/material.dart';
import '../widgets/tribe_app_bar.dart';

class PlaceScreen extends StatelessWidget {
  const PlaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TribeAppBar(
      ),
      body: const Center(
        child: Text(
          'Карта барбершопов\n(заглушка)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}