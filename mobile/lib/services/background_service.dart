import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'api_service.dart';

// ── Notification Channel ──
const notificationChannelId = 'familyguard_foreground';
const notificationId = 888;

// ── Background Service Initialization ──
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // Create the persistent notification channel for the foreground service
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'FamilyGuard Protection',
    description: 'Surveillance du temps d\'écran en arrière-plan',
    importance: Importance.low, // low = no sound, but visible
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // We start it manually after login
      isForegroundMode: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'FamilyGuard',
      initialNotificationContent: 'Protection active',
      foregroundServiceNotificationId: notificationId,
      foregroundServiceTypes: [AndroidForegroundType.dataSync],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// iOS background handler (required but minimal)
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

// ── The main background loop ──
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Hive in the background isolate
  await Hive.initFlutter();
  final box = await Hive.openBox('time_rules');
  final usageBox = await Hive.openBox('usage_tracking');

  // Listen for stop command from Flutter UI
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen for manual lock/unlock commands
  service.on('lockNow').listen((event) {
    _triggerLock(service);
  });

  service.on('unlockNow').listen((event) {
    _triggerUnlock(service);
  });

  // ── Main monitoring timer: runs every 60 seconds ──
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    try {
      await _checkTimeRules(box, usageBox, service);
    } catch (e) {
      // Silently continue — don't crash the background service
    }
  });

  // Also check immediately on startup
  await _checkTimeRules(box, usageBox, service);
}

Future<void> _checkTimeRules(Box box, Box usageBox, ServiceInstance service) async {
  final now = TimeOfDay.now();
  final today = DateTime.now().toIso8601String().substring(0, 10); // "2026-06-09"

  // ── Check all cached profile statuses ──
  final keys = box.keys.where((k) => k.toString().startsWith('status_')).toList();

  for (final key in keys) {
    final status = box.get(key);
    if (status == null || status is! Map) continue;

    // ── 1. Manual Block & Exam Mode ──
    if (status['is_manually_blocked'] == true) {
      _triggerLock(service);
      _updateNotification(service, 'Appareil bloqué manuellement 🔒');
      continue;
    }
    
    // Exam mode (lock logic handled similarly)
    if (status['is_exam_mode'] == true) {
      _triggerLock(service);
      _updateNotification(service, 'Mode Examen actif 📚');
      continue;
    }

    // ── 2. Bedtime / Couvre-feu Check ──
    final startStr = status['bedtime_start'] as String?;
    final endStr = status['bedtime_end'] as String?;
    if (startStr != null && endStr != null) {
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      final bedtimeStart = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      final bedtimeEnd = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      if (_isInBedtime(now, bedtimeStart, bedtimeEnd)) {
        _triggerLock(service);
        _updateNotification(service, 'Couvre-feu actif — appareil verrouillé 🌙');
        continue;
      }
    }

    // ── 3. Daily Limit Check ──
    if (status['has_limit'] == true) {
      final limitMinutes = status['daily_limit_minutes'] as int? ?? 120;
      final profileIdStr = key.toString().replaceFirst('status_', '');
      final todayUsageKey = 'usage_${profileIdStr}_$today';

      // Get today's accumulated usage (in minutes) from usageBox
      final usedMinutes = usageBox.get(todayUsageKey, defaultValue: status['minutes_used'] ?? 0) as int;

      // Increment by 1 minute (since we check every 60s)
      final newUsed = usedMinutes + 1;
      usageBox.put(todayUsageKey, newUsed);

      // Report usage to the server in background if possible
      try {
        final profileId = int.parse(profileIdStr);
        await ApiService.reportTimeUsage(profileId, 1);
      } catch (_) {}

      if (newUsed >= limitMinutes) {
        _triggerLock(service);
        _updateNotification(service, 'Limite quotidienne atteinte — $newUsed/${limitMinutes}min ⏱️');
        continue;
      } else {
        final remaining = limitMinutes - newUsed;
        _updateNotification(service, 'Protection active — ${remaining}min restantes');
      }
    } else {
      _updateNotification(service, 'Protection active — Temps illimité');
    }
  }
}

bool _isInBedtime(TimeOfDay now, TimeOfDay start, TimeOfDay end) {
  final nowMinutes = now.hour * 60 + now.minute;
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;

  // Handle overnight bedtime (e.g., 21:00 → 07:00)
  if (startMinutes > endMinutes) {
    return nowMinutes >= startMinutes || nowMinutes < endMinutes;
  } else {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
}

void _triggerLock(ServiceInstance service) {
  service.invoke('triggerLock');
}

void _triggerUnlock(ServiceInstance service) {
  service.invoke('triggerUnlock');
}

void _updateNotification(ServiceInstance service, String content) {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'FamilyGuard',
      content: content,
    );
  }
}
