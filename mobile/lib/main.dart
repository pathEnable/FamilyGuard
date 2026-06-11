import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/firebase_service.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('time_rules');
  await Hive.openBox('usage_tracking');
  await initializeBackgroundService();
  await FirebaseService.initialize();
  
  // Intercepter les erreurs de Flutter pour Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Intercepter les erreurs asynchrones
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: SafeChildApp()));
}

class SafeChildApp extends StatefulWidget {
  const SafeChildApp({super.key});

  @override
  SafeChildAppState createState() => SafeChildAppState();
}

class SafeChildAppState extends State<SafeChildApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  bool _hasSeenOnboarding = false;

  static const _lockChannel = MethodChannel('com.familyguard/lock');

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _listenToBackgroundService();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    final token = await ApiService.getToken();
    if (token != null) {
      // Start background monitoring service
      final service = FlutterBackgroundService();
      service.startService();
    }
    setState(() {
      _hasSeenOnboarding = hasSeenOnboarding;
      _isAuthenticated = token != null;
      _isLoading = false;
    });
  }

  /// Listen for lock/unlock events from the background isolate
  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();

    service.on('triggerLock').listen((_) async {
      try {
        await _lockChannel.invokeMethod('startLock');
      } catch (e) {
        debugPrint('Lock failed: $e');
      }
    });

    service.on('triggerUnlock').listen((_) async {
      try {
        await _lockChannel.invokeMethod('stopLock');
      } catch (e) {
        debugPrint('Unlock failed: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    Widget homeWidget;
    if (!_hasSeenOnboarding) {
      homeWidget = const OnboardingScreen();
    } else {
      homeWidget = _isAuthenticated ? const DashboardScreen() : const LoginScreen();
    }

    return MaterialApp(
      title: 'FamilyGuard',
      debugShowCheckedModeBanner: false,
      theme: SafeChildTheme.lightTheme,
      home: homeWidget,
    );
  }
}

