import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io' show Platform;
import 'api_service.dart';

class LocationService {
  static const _platform = MethodChannel('com.familyguard/geofence');

  static Future<void> initialize() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Test if location services are enabled.
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return;
      }

      // Instead of continuous polling, fetch SafeZones and register with native Geofencing API
      await _setupNativeGeofences();

    } catch (e) {
      debugPrint('Error initializing LocationService: $e');
    }
  }

  static Future<void> _setupNativeGeofences() async {
    if (!Platform.isAndroid) return; // Geofencing optimized only for Android native

    final box = Hive.box('time_rules');
    final profileId = box.get('current_profile_id') as int?;

    if (profileId != null) {
      try {
        final safeZones = await ApiService.getSafeZones(profileId);
        
        final activeZones = safeZones.where((z) => z['is_active'] == true).toList();
        
        if (activeZones.isEmpty) {
          await _platform.invokeMethod('removeAllGeofences');
          debugPrint("No active safe zones. Native geofences cleared.");
          return;
        }

        final zonesToRegister = activeZones.map((z) => {
          'name': z['name'],
          'latitude': z['latitude'],
          'longitude': z['longitude'],
          'radius': z['radius_meters'],
        }).toList();

        await _platform.invokeMethod('setupGeofences', {'zones': zonesToRegister});
        debugPrint("Native geofences setup complete for ${zonesToRegister.length} zones.");

      } catch (e) {
        debugPrint("Failed to setup native geofences: $e");
      }
    }
  }

  static void stop() {
    if (Platform.isAndroid) {
      _platform.invokeMethod('removeAllGeofences');
    }
  }
}
