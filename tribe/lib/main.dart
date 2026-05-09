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
import 'screens/master/master_home_screen.dart'; // ✅ Добавлен импорт

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
        '/master-home': (context) => const MasterHomeScreen(), // ✅ Добавлен маршрут для мастера
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
  
  // ✅ Ключевые флаги
  bool _isLoading = true;           // Загружается ли приложение
  bool _isRoleChecked = false;      // ✅ Проверена ли роль
  int? _userRoleId;                 // Роль пользователя

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

  /// ✅ Инициализация при старте
  Future<void> _initializeAuth() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      
      if (session != null) {
        // Проверяем токен
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
                  _isRoleChecked = true;
                  _userRoleId = null;
                });
              }
              return;
            }
          }
        }
        
        // ✅ Сначала проверяем роль, ПОТОМ разрешаем рендер
        await _checkUserRole();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isRoleChecked = true;  // ✅ Роль проверена!
          });
        }
      } else {
        // Нет сессии — не админ
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isRoleChecked = true;  // ✅ Проверка завершена (нет пользователя)
            _userRoleId = null;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Ошибка инициализации: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRoleChecked = true;  // ✅ Даже при ошибке — проверка "завершена"
        });
      }
    }
  }

  /// ✅ Проверка роли пользователя
  Future<void> _checkUserRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      debugPrint('🔍 Проверяем роль для: ${user.id}');

      final response = await Supabase.instance.client
          .from('users')
          .select('role_id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      if (response == null) {
        debugPrint('⚠️ Запись пользователя не найдена');
        return;
      }

      final roleId = response['role_id'] as int?;
      debugPrint('📊 Role ID: $roleId');
      
      setState(() {
        _userRoleId = roleId;
      });

      // ✅ Навигация ТОЛЬКО после того, как роль сохранена в state
      if (mounted) {
        if (roleId == 3) {
          // Администратор
          debugPrint('👑 Админ найден, перенаправляем...');
          Navigator.of(context).pushReplacementNamed('/admin');
        } else if (roleId == 2) {
          // ✅ Мастер
          debugPrint('✂️ Мастер найден, перенаправляем...');
          Navigator.of(context).pushReplacementNamed('/master-home');
        }
        // Клиенты (role_id == 1) остаются на главном экране
      }

    } catch (e) {
      debugPrint('❌ Ошибка проверки роли: $e');
    }
  }

  /// ✅ Слушатель изменений авторизации
  void _listenToAuthChanges() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final event = data.event;
        debugPrint('🔄 Auth event: $event');
        
        if (!mounted) return;
        
        if (event == AuthChangeEvent.signedIn) {
          // ✅ Пользователь вошёл — ПЕРЕЗАПУСКАЕМ проверку
          debugPrint('📥 SignedIn — проверяем роль...');
          setState(() {
            _isLoading = true;
            _isRoleChecked = false;  // ✅ Сбрасываем флаг
            _userRoleId = null;
          });
          
          await _checkUserRole();
          
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isRoleChecked = true;  // ✅ Роль проверена
            });
          }
        } else if (event == AuthChangeEvent.signedOut) {
          debugPrint('📤 SignedOut');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isRoleChecked = true;
              _userRoleId = null;
            });
          }
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('🔄 Token refreshed');
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
    // ✅ ГЛАВНОЕ ИСПРАВЛЕНИЕ:
    // Не рендерим НИЧЕГО, пока роль не проверена
    if (_isLoading || !_isRoleChecked) {
      debugPrint('⏳ Ждём проверки роли... (isLoading: $_isLoading, isRoleChecked: $_isRoleChecked)');
      return const Scaffold(
        backgroundColor: Color(0xFF363636),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // ✅ Нет сессии → вход
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      debugPrint('🔐 LoginScreen');
      return const LoginScreen();
    }

    // ✅ Админ → админка
    if (_userRoleId == 3) {
      debugPrint('👑 AdminDashboardScreen');
      return const AdminDashboardScreen();
    }

    // ✅ Мастер → мастер-интерфейс
    if (_userRoleId == 2) {
      debugPrint('✂️ MasterHomeScreen');
      return const MasterHomeScreen();
    }

    // ✅ Клиент → главный экран
    debugPrint('👤 MainScreen (role_id: ${_userRoleId ?? "null"})');
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