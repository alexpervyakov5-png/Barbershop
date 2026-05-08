import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Экраны приложения
import 'screens/home_screen.dart';
import 'screens/service_screen.dart';
import 'screens/master_screen.dart';
import 'screens/place_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/master_works_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';

// Экраны авторизации
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

const supabaseUrl = 'https://lizdqsfjnzzizitglgvg.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxpemRxc2Zqbnp6aXppdGdsZ3ZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NDczNzEsImV4cCI6MjA4MTMyMzM3MX0.HJyeDpdWVrDqV84km62VBIJhbbLwIGmsfk2uP0-dWa8';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      navigatorKey: navigatorKey,
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
      home: const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin': (context) => const AdminDashboardScreen(),
        '/master-works': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return MasterWorksScreen(
            masterId: args['masterId'] as String,
            masterName: args['masterName'] as String,
            canEdit: args['canEdit'] as bool? ?? false,
          );
        },
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  
  bool _isLoading = true;
  bool _isCheckingRole = false;
  bool _isAuthenticated = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _listenToAuthChanges();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// ✅ Инициализация при старте приложения
  Future<void> _initializeAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        // Проверяем, не истёк ли токен
        final expiresAtInt = session.expiresAt;
        if (expiresAtInt != null && expiresAtInt > 0) {
          final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiresAtInt * 1000);
          if (expiresAt.isBefore(DateTime.now())) {
            try {
              await Supabase.instance.client.auth.refreshSession();
            } catch (_) {
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _isAuthenticated = false;
                  _isAdmin = false;
                });
              }
              return;
            }
          }
        }
        
        // ✅ Проверяем роль пользователя
        await _checkUserRole();
        
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
      } else {
        // Нет сессии
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isAdmin = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка инициализации: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  /// ✅ Проверка роли пользователя
  Future<void> _checkUserRole() async {
    if (_isCheckingRole) return;
    _isCheckingRole = true;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _isCheckingRole = false;
        return;
      }

      debugPrint('🔍 Проверяем роль для пользователя: ${user.id}');

      final response = await Supabase.instance.client
          .from('users')
          .select('role_id, email')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) {
        _isCheckingRole = false;
        return;
      }

      if (response == null) {
        debugPrint('⚠️ Запись пользователя не найдена в таблице users');
        _isCheckingRole = false;
        return;
      }

      final roleId = response['role_id'] as int?;
      final email = response['email'] as String?;
      
      debugPrint('📊 Role ID: $roleId, Email: $email');
      
      final isAdmin = roleId == 3;

      setState(() {
        _isAdmin = isAdmin;
      });

      debugPrint('👑 Is Admin: $isAdmin');

      // ✅ Если админ — перенаправляем
      if (isAdmin && mounted) {
        Navigator.of(context).pushReplacementNamed('/admin');
      }

    } catch (e) {
      debugPrint('❌ Ошибка проверки роли: $e');
    } finally {
      _isCheckingRole = false;
    }
  }

  /// ✅ Слушаем изменения авторизации
  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        debugPrint('🔄 Auth event: $event');
        
        if (!mounted) return;
        
        if (event == AuthChangeEvent.signedIn) {
          // ✅ Пользователь вошёл — проверяем роль
          debugPrint('📥 Пользователь вошёл, проверяем роль...');
          setState(() {
            _isLoading = true;
            _isAuthenticated = true;
          });
          
          await _checkUserRole();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        } else if (event == AuthChangeEvent.signedOut) {
          // ✅ Пользователь вышел
          debugPrint('📤 Пользователь вышел');
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
              _isAdmin = false;
              _isLoading = false;
            });
          }
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          // ✅ Токен обновился — перепроверяем роль
          debugPrint('🔄 Токен обновлён');
          await _checkUserRole();
        }
      },
      onError: (error) {
        debugPrint('❌ Ошибка в onAuthStateChange: $error');
        if (error.toString().contains('JWT expired')) {
          Supabase.instance.client.auth.signOut();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Показываем загрузку
    if (_isLoading) {
      debugPrint('⏳ Загрузка...');
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // ✅ Нет сессии → экран входа
    if (!_isAuthenticated) {
      debugPrint('🔐 Показываем LoginScreen');
      return const LoginScreen();
    }

    // ✅ Админ → админ-панель
    if (_isAdmin) {
      debugPrint('👑 Показываем AdminDashboardScreen');
      return const AdminDashboardScreen();
    }

    // ✅ Обычный пользователь → главный экран
    debugPrint('👤 Показываем MainScreen');
    return const MainScreen();
  }
}

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
            icon: Image.asset(
              'assets/icons/icon_home${_currentIndex == 0 ? '1' : ''}.png',
              width: 24,
              height: 24,
            ),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/icon_service${_currentIndex == 1 ? '1' : ''}.png',
              width: 24,
              height: 24,
            ),
            label: 'Сервис',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/icon_master${_currentIndex == 2 ? '1' : ''}.png',
              width: 24,
              height: 24,
            ),
            label: 'Мастер',
          ),
          BottomNavigationBarItem(
            icon: Image.asset(
              'assets/icons/icon_place${_currentIndex == 3 ? '1' : ''}.png',
              width: 24,
              height: 24,
            ),
            label: 'Карта',
          ),
        ],
      ),
    );
  }
}