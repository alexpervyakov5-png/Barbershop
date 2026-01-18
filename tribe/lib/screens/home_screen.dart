// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../widgets/tribe_app_bar.dart'; // мы вынесем AppBar отдельно чуть позже

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TribeAppBar(
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Верхнее изображение
            Image.asset(
              'assets/images/home_img.png',
              width: double.infinity,
              fit: BoxFit.cover,
              height: 200,
            ),

            const SizedBox(height: 24),

            // Заголовок "О нас"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'О нас',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Описание
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Приветствуем тебя в Tribe 🤝 Мы - авторский проект мужской парикмахерской, предлагающий премиальное качество услуг, радушную приятельскую обстановку и удобное расположение в центре Кирова.\n\n[TRIBE] — в переводе с англ., племя, клан\n\n✂ Трудимся каждый день с 10.00 до 21.00',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Блок "Акции"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Акции',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Изображение акции с кнопкой

            Stack(
              children: [
                // Фоновое изображение
                Image.asset(
                  'assets/images/first_haircut.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: 290,
                ),

                Positioned(
                  
                  left: null,        
                  right: 34,        
                  top: null,         
                  bottom: 34,        

                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Акция выбрана!')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white, width: 2),
                      backgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 12.5,
                      ),
                    ),
                    child: const Text(
                      'От 1090₽',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}