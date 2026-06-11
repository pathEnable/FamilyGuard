import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VpnService {
  static const MethodChannel _channel = MethodChannel('com.familyguard/vpn');

  /// Démarre le VPN local pour bloquer l'accès internet aux applications listées.
  static Future<bool> startVpn(List<String> blockedApps) async {
    try {
      final bool result = await _channel.invokeMethod('startVpn', {
        'blockedApps': blockedApps,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint("Erreur lors du démarrage du VPN: '${e.message}'.");
      return false;
    }
  }

  /// Arrête le VPN local, restaurant l'accès internet pour toutes les applications.
  static Future<bool> stopVpn() async {
    try {
      final bool result = await _channel.invokeMethod('stopVpn');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Erreur lors de l'arrêt du VPN: '${e.message}'.");
      return false;
    }
  }
}
