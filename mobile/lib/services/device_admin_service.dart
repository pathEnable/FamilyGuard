import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceAdminService {
  static const MethodChannel _channel = MethodChannel('com.familyguard/device_admin');

  /// Vérifie si l'application est actuellement un administrateur de l'appareil
  static Future<bool> isDeviceAdminEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isDeviceAdminEnabled');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Erreur lors de la vérification du Device Admin: '${e.message}'.");
      return false;
    }
  }

  /// Demande à l'utilisateur d'activer les droits d'administration de l'appareil.
  /// Affiche l'écran système d'Android.
  static Future<bool> requestDeviceAdmin() async {
    try {
      final bool result = await _channel.invokeMethod('requestDeviceAdmin');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Erreur lors de la demande du Device Admin: '${e.message}'.");
      return false;
    }
  }
}
