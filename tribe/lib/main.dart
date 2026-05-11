import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Экраны приложения
import 'screens/home_screen.dart';
import 'screens/service_screen.dart';
import 'screens/master_screen.dart';
import 'screens/place_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/master_works_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/master/master_home_screen.dart';

// Экраны авторизации
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

const supabaseUrl = 'https://lizdqsfjnzzizitglgvg.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpemRxc2Zqbnp6aXppdGdsZ3ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NDczNzEsImV4cCI6MjA4MTMyMzM3MX0.HJyeDpdWVrDqV84km62VBIJhbbLwIGmsfk2uP0-dWa8';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Инициализируем русскую локаль для форматирования дат
  await initializeDateFormatting('ru', null);
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: kDebugMode,
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
      // ✅ Настройки локализации
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFF363636),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF363636),
          foregroundColor: Colors.white,
          elevation: 0,
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
          type: BottomNavigationBarType.fixed,
        ),
      ),
      // ✅ При старте проверяем: есть ли сессия?
      home: const StartupScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/master-home': (context) => const MasterHomeScreen(),
        '/master-works': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MasterWorksScreen(
            masterId: args?['masterId'] as String? ?? '',
            masterName: args?['masterName'] as String? ?? 'Мастер',
            canEdit: args?['canEdit'] as bool? ?? false,
          );
        },
      },
    );
  }
}

/// ✅ Экран запуска: решает, куда идти
class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    
    // Если есть сессия — проверяем роль
    if (session != null) {
      return const RoleCheckScreen();
    }
    
    // Нет сессии — показываем вход
    return const LoginScreen();
  }
}

/// ✅ Экран проверки роли (используется после входа)
class RoleCheckScreen extends StatefulWidget {
  const RoleCheckScreen({super.key});

  @override
  State<RoleCheckScreen> createState() => _RoleCheckScreenState();
}

class _RoleCheckScreenState extends State<RoleCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        // Сессия пропала — возвращаемся на вход
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

      debugPrint('🔍 Checking role for: ${session.user.id}');

      final response = await Supabase.instance.client
          .from('users')
          .select('role_id')
          .eq('user_id', session.user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('⏱️ Timeout');
            return null;
          });

      if (!mounted) return;

      final roleId = response?['role_id'] as int?;
      debugPrint('📊 Role ID: $roleId');

      Widget target;
      if (roleId == 3) {
        target = const AdminDashboardScreen();
      } else if (roleId == 2) {
        target = const MasterHomeScreen();
      } else {
        target = const MainScreen();
      }

      // ✅ ЗАМЕНЯЕМ этот экран на целевой (убираем RoleCheckScreen из стека)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => target),
      );

    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        // При ошибке — на главный экран
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF363636),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Загрузка...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// Главный экран для клиентов
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