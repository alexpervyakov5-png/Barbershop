import 'package:flutter/material.dart';
import '../widgets/tribe_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TribeAppBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ ИСПРАВЛЕНО: Добавлен errorBuilder для Image.asset
            Image.asset(
              'assets/images/home_img.png',
              width: double.infinity,
              fit: BoxFit.cover,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  width: double.infinity,
                  color: const Color(0xFF444444),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.white54, size: 48),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
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

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Приветствуем тебя в Tribe 🤝 Мы - авторский проект мужской парикмахерской, предлагающий премиальное качество услуг, радушную приятельскую обстановку и удобное расположение в центре Кирова.\n\n[TRIBE] — в переводе с англ., племя, клан\n\n✂ Трудимся каждый день с 10.00 до 21.00',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 32),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
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

            Stack(
              children: [
                Image.asset(
                  'assets/images/first_haircut.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  height: 290,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 290,
                      width: double.infinity,
                      color: const Color(0xFF444444),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.white54, size: 48),
                      ),
                    );
                  },
                ),

                // ✅ ИСПРАВЛЕНО: Использование Alignment вместо Positioned с null
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 34, bottom: 34),
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