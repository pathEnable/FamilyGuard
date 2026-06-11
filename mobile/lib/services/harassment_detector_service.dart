import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'api_service.dart';

class HarassmentDetectorService {
  static StreamSubscription<ServiceNotificationEvent>? _subscription;

  // Liste de mots-clés (simplifiée pour l'exemple)
  static const List<String> _badWords = [
    'idiot', 'débile', 'moche', 'tuer', 'suicide', 'haine',
    'nul', 'stupide', 'connard', 'salope', 'meurt'
  ];

  static Future<void> initialize() async {
    try {
      debugPrint("Initializing HarassmentDetectorService");
      
      bool isGranted = await NotificationListenerService.isPermissionGranted();
      if (!isGranted) {
        debugPrint("Requesting Notification Listener Permission");
        isGranted = await NotificationListenerService.requestPermission();
      }

      if (isGranted) {
        debugPrint("Notification Listener Permission Granted. Listening...");
        _subscription = NotificationListenerService.notificationsStream.listen((event) {
          _analyzeNotification(event);
        });
      } else {
        debugPrint("Notification Listener Permission Denied.");
      }
    } catch (e) {
      debugPrint("Failed to initialize HarassmentDetectorService: $e");
    }
  }

  static Future<void> _analyzeNotification(ServiceNotificationEvent event) async {
    // We only care about new notifications that have text
    if (event.content == null || event.content!.isEmpty) return;
    
    // Optional: filter out system notifications, only check messaging apps
    // if (event.packageName != "com.whatsapp" && ...) return;

    final text = event.content!.toLowerCase();
    
    bool detected = false;
    for (String word in _badWords) {
      if (text.contains(word)) {
        detected = true;
        break;
      }
    }

    if (detected) {
      debugPrint("🚨 HARASSMENT DETECTED in notification from ${event.packageName} 🚨");
      
      final box = Hive.box('time_rules');
      final profileId = box.get('current_profile_id') as int?;

      if (profileId != null) {
        try {
          // We don't send the message content for privacy reasons, only an alert
          await ApiService.reportCyberbullying(profileId, event.packageName ?? 'inconnu');
        } catch (e) {
          debugPrint("Failed to report cyberbullying: $e");
        }
      }
    }
  }

  static void stop() {
    _subscription?.cancel();
  }
}
