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
import 'screens/admin/admin_profile_screen.dart';
import 'screens/master/master_home_screen.dart';

// Экраны авторизации
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

// Utils
import 'utils/cache_service.dart';

const supabaseUrl = 'https://lizdqsfjnzzizitglgvg.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpemRxc2Zqbnp6aXppdGdsZ3ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NDczNzEsImV4cCI6MjA4MTMyMzM3MX0.HJyeDpdWVrDqV84km62VBIJhbbLwIGmsfk2uP0-dWa8';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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
      home: const StartupScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/services': (context) => const ServiceScreen(), // ✅ ДОБАВЛЕНО: Маршрут на услуги
        '/admin': (context) => const AdminDashboardScreen(),
        '/admin-profile': (context) => const AdminProfileScreen(),
        '/master-home': (context) => const MasterHomeScreen(),
        '/role-check': (context) => const RoleCheckScreen(),
        '/master-works': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return MasterWorksScreen(
            masterId: args?['masterId'] as String? ?? '',
            masterName: args?['masterName'] as String? ?? 'Мастер',
            canEdit: args?['canEdit'] as bool? ?? false,
          );
        },
      },
      builder: (context, child) {
        return child!;
      },
    );
  }
}

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    
    if (session != null) {
      return const RoleCheckScreen();
    }
    
    return const LoginScreen();
  }
}

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
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
        return;
      }

      final cache = CacheService();
      int? roleId = cache.get<int>('user_role_${session.user.id}');

      if (roleId == null) {
        final response = await Supabase.instance.client
            .from('users')
            .select('role_id')
            .eq('user_id', session.user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));

        if (!mounted) return;
        roleId = response?['role_id'] as int?;
        
        if (roleId != null) {
          await cache.set('user_role_${session.user.id}', roleId, 
            duration: const Duration(minutes: 30));
        }
      }

      if (!mounted) return;
      debugPrint('📊 Role ID: $roleId');

      Widget target;
      if (roleId == 3) {
        target = const AdminDashboardScreen();
      } else if (roleId == 2) {
        target = const MasterHomeScreen();
      } else {
        target = const MainScreen();
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => target),
      );

    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = const [
    HomeScreen(),
    ServiceScreen(),
    MasterScreen(),
    PlaceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
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