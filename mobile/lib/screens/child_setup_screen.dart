import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../theme.dart';
import 'dashboard_screen.dart';
import '../services/device_admin_service.dart';
import 'package:flutter/services.dart';

class ChildSetupScreen extends StatefulWidget {
  const ChildSetupScreen({super.key});

  @override
  State<ChildSetupScreen> createState() => _ChildSetupScreenState();
}

class _ChildSetupScreenState extends State<ChildSetupScreen> {
  bool _isSettingUp = false;

  Future<void> _completeSetup() async {
    setState(() {
      _isSettingUp = true;
    });

    try {
      // Démarrer le service en arrière-plan pour qu'il tourne 24/24
      final service = FlutterBackgroundService();
      await service.startService();
      
      // Demander la permission d'affichage par-dessus les autres apps (System Alert Window)
      const lockChannel = MethodChannel('com.familyguard/lock');
      await lockChannel.invokeMethod('requestOverlayPermission');
      
      // Demander les droits d'administrateur de l'appareil
      await DeviceAdminService.requestDeviceAdmin();
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('setup_completed', true);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de configuration: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSettingUp = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Configuration de l\'appareil', style: TextStyle(color: SafeChildColors.textMain)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.security,
                size: 100,
                color: SafeChildColors.primary,
              ),
              const SizedBox(height: 32),
              const Text(
                'Protéger cet appareil 24/7',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: SafeChildColors.textMain,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pour assurer que FamilyGuard fonctionne même sans connexion internet et 24h/24, nous devons configurer l\'appareil et activer les protections en arrière-plan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              _isSettingUp
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _completeSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SafeChildColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Activer la protection',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
