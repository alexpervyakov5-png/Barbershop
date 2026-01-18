// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Экраны приложения
import 'screens/home_screen.dart';
import 'screens/service_screen.dart';
import 'screens/master_screen.dart';
import 'screens/place_screen.dart';

// Экраны авторизации
import '/auth/login_screen.dart';

const supabaseUrl = 'https://lizdqsfjnzzizitglgvg.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpemRxc2Zqbnp6aXppdGdsZ3ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NDczNzEsImV4cCI6MjA4MTMyMzM3MX0.HJyeDpdWVrDqV84km62VBIJhbbLwIGmsfk2uP0-dWa8';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tribe',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF363636),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF363636),
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          surface: const Color(0xFF363636),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF363636),
          selectedItemColor: Colors.white,
          unselectedItemColor: Color(0xFFD6D6D6),
          unselectedLabelStyle: TextStyle(fontSize: 12),
          selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      // ✅ Точка входа: проверка авторизации
      home: const AuthGate(),
    );
  }
}

// 🔒 Проверка сессии: если залогинен — MainScreen, иначе — LoginScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const MainScreen() : const LoginScreen();
  }
}

// 🏠 Основной экран с нижней навигацией
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const ServiceScreen(),
    const MasterScreen(),
    const PlaceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        items: [
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/icon_home${_currentIndex == 0 ? '1' : ''}.png', width: 24, height: 24),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/icon_service${_currentIndex == 1 ? '1' : ''}.png', width: 24, height: 24),
            label: 'Сервис',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/icon_master${_currentIndex == 2 ? '1' : ''}.png', width: 24, height: 24),
            label: 'Мастер',
          ),
          BottomNavigationBarItem(
            icon: Image.asset('assets/icons/icon_place${_currentIndex == 3 ? '1' : ''}.png', width: 24, height: 24),
            label: 'Карта',
          ),
        ],
      ),
    );
  }
}