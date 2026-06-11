import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../services/api_service.dart';
import 'quests_screen.dart';
import '../services/harassment_detector_service.dart';
import '../services/device_admin_service.dart';
import '../services/vpn_service.dart';
import '../services/location_service.dart';
import '../services/websocket_service.dart';
import '../utils/bloom_filter.dart';
import 'rewards_screen.dart';


class ChildDashboardScreen extends ConsumerStatefulWidget {
  final int profileId;
  final String profileName;

  const ChildDashboardScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  ChildDashboardScreenState createState() => ChildDashboardScreenState();
}

class ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with TickerProviderStateMixin {
  static const platform = MethodChannel('com.familyguard/lock');

  // Time data
  int _dailyLimitMinutes = 0;
  int _minutesUsed = 0;
  int _minutesRemaining = 0;
  bool _isBedtimeBlocked = false;
  bool _isManuallyBlocked = false;
  bool _isExamMode = false;
  List<String> _allowedApps = [];
  List<String> _blockedNetworkApps = [];
  bool _isLoading = true;
  bool _hasLimit = false;
  String? _bedtimeStartStr;
  String? _bedtimeEndStr;

  // SOS state
  bool _isSosTriggered = false;
  double _sosHoldProgress = 0.0;
  Timer? _sosTimer;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _statusTimer;
  StreamSubscription? _wsSubscription;

  // Simulator
  BloomFilter? _bloomFilter;
  final TextEditingController _urlController = TextEditingController();
  bool? _isUrlBlocked;

  // PIN protection
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadTimeStatus();
    _loadBloomFilter();
    _checkPin();
    _checkDeviceAdmin();
    LocationService.initialize();
    HarassmentDetectorService.initialize();
    
    // Connect to WebSocket and listen for events
    WebSocketService.instance.connect();
    _wsSubscription = WebSocketService.instance.messages.listen((msg) {
      if (msg['type'] == 'rules_updated' && msg['profile_id'] == widget.profileId) {
        debugPrint('WS: Règles mises à jour reçues. Rechargement du statut...');
        _loadTimeStatus();
      }
    });

    // Check status every 60 seconds as a fallback
    _statusTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _loadTimeStatus();
    });
  }

  Future<void> _saveOfflineStatus() async {
    final box = Hive.box('time_rules');
    final statusData = {
      'daily_limit_minutes': _dailyLimitMinutes,
      'minutes_used': _minutesUsed,
      'minutes_remaining': _minutesRemaining,
      'is_bedtime_blocked': _isBedtimeBlocked,
      'is_manually_blocked': _isManuallyBlocked,
      'is_exam_mode': _isExamMode,
      'has_limit': _hasLimit,
      'bedtime_start': _bedtimeStartStr,
      'bedtime_end': _bedtimeEndStr,
      'blocked_network_apps': _blockedNetworkApps,
    };
    await box.put('status_${widget.profileId}', statusData);
  }

  Future<void> _loadOfflineStatus() async {
    final box = Hive.box('time_rules');
    final statusData = box.get('status_${widget.profileId}');
    if (statusData != null && mounted) {
      setState(() {
        _dailyLimitMinutes = statusData['daily_limit_minutes'] ?? 0;
        _minutesUsed = statusData['minutes_used'] ?? 0;
        _hasLimit = statusData['has_limit'] ?? false;
        _isManuallyBlocked = statusData['is_manually_blocked'] ?? false;
        _isBedtimeBlocked = statusData['is_bedtime_blocked'] ?? false;
        _isExamMode = statusData['is_exam_mode'] ?? false;
        _bedtimeStartStr = statusData['bedtime_start'];
        _bedtimeEndStr = statusData['bedtime_end'];
        _blockedNetworkApps = List<String>.from(statusData['blocked_network_apps'] ?? []);
        _minutesRemaining = _hasLimit ? max(0, _dailyLimitMinutes - _minutesUsed) : 0;
        _isLoading = false;

        _applyVpnRules();

        if (_isExamMode || _isBedtimeBlocked || _isManuallyBlocked || (_hasLimit && _minutesRemaining <= 0)) {
          _invokeStartLock();
        }
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer?.cancel();
    _sosTimer?.cancel();
    _urlController.dispose();
    LocationService.stop();
    HarassmentDetectorService.stop();
    _wsSubscription?.cancel();
    WebSocketService.instance.disconnect();
    super.dispose();
  }

  Future<void> _loadTimeStatus() async {
    try {
      final data = await ApiService.getTimeStatus(widget.profileId);
      if (!mounted) return;
      setState(() {
        _dailyLimitMinutes = data['daily_limit_minutes'] ?? 0;
        _minutesUsed = data['minutes_used'] ?? 0;
        _minutesRemaining = data['minutes_remaining'] ?? 0;
        _isBedtimeBlocked = data['is_bedtime_blocked'] ?? false;
        _isManuallyBlocked = data['is_manually_blocked'] ?? false;
        _isExamMode = data['is_exam_mode'] ?? false;
        _bedtimeStartStr = data['bedtime_start'];
        _bedtimeEndStr = data['bedtime_end'];
        _allowedApps = List<String>.from(data['allowed_apps'] ?? []);
        _blockedNetworkApps = List<String>.from(data['blocked_network_apps'] ?? []);
        _hasLimit = data['daily_limit_minutes'] != null;
        _isLoading = false;

        _applyVpnRules();

        // Trigger native lock if necessary
        if (_isExamMode) {
          // Exam mode: lock with whitelist
          _invokeStartLock();
        } else if (_isBedtimeBlocked || _isManuallyBlocked || (_hasLimit && _minutesRemaining <= 0)) {
          _invokeStartLock();
        } else {
          platform.invokeMethod('stopLock');
        }
        
        _saveOfflineStatus();
      });
    } catch (e) {
      // API call failed (e.g. no internet). Load from local storage.
      await _loadOfflineStatus();
    }
  }

  void _applyVpnRules() {
    if (_blockedNetworkApps.isNotEmpty) {
      VpnService.startVpn(_blockedNetworkApps);
    } else {
      VpnService.stopVpn();
    }
  }

  /// Centralized helper to invoke the native startLock method
  /// with exam mode parameters when applicable.
  void _invokeStartLock() {
    platform.invokeMethod('startLock', {
      'isExamMode': _isExamMode,
      'allowedApps': _allowedApps,
    });
  }

  Future<void> _loadBloomFilter() async {
    try {
      final bytes = await ApiService.downloadBloomFilter();
      if (!mounted) return;
      setState(() {
        _bloomFilter = BloomFilter.fromBytes(bytes);
      });
    } catch (e) {
      debugPrint('Erreur Bloom Filter: $e');
    }
  }

  Future<void> _checkPin() async {
    try {
      final has = await ApiService.hasPin(widget.profileId);
      if (!mounted) return;
      setState(() => _hasPin = has);
    } catch (_) {}
  }

  Future<void> _checkDeviceAdmin() async {
    final isEnabled = await DeviceAdminService.isDeviceAdminEnabled();
    if (!isEnabled && mounted) {
      // Afficher un dialogue forçant l'activation pour que l'enfant ne puisse pas
      // simplement ignorer l'étape
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text("Sécurité Requise"),
          content: const Text(
            "FamilyGuard a besoin d'être administrateur de cet appareil pour fonctionner de manière sécurisée et empêcher sa désinstallation.\n\nVeuillez demander à vos parents de l'activer.",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await DeviceAdminService.requestDeviceAdmin();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  _checkDeviceAdmin(); // Re-check after returning
                }
              },
              child: const Text("Activer"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showPinDialog() async {
    final pinController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text('Code PIN Parent'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Entrez le code PIN pour quitter l\'interface enfant.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '• • • •',
                      errorText: errorText,
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annuler', style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    if (pin.isEmpty) return;
                    try {
                      final valid = await ApiService.verifyPin(widget.profileId, pin);
                      if (!ctx.mounted) return;
                      if (valid) {
                        Navigator.of(ctx).pop(true);
                      } else {
                        setDialogState(() => errorText = 'PIN incorrect');
                      }
                    } catch (_) {
                      setDialogState(() => errorText = 'PIN incorrect');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Valider', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _confirmDisconnectEarly() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Veux-tu vraiment te déconnecter maintenant ? '
          'L\'appareil sera verrouillé pour le reste de la journée et tu gagneras des points de confiance !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _disconnectEarly();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Oui, je me déconnecte', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _disconnectEarly() async {
    try {
      final res = await ApiService.disconnectEarly(widget.profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Déconnecté avec succès !'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _loadTimeStatus(); // This will lock the device
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _checkUrl() async {
    if (_bloomFilter == null || _urlController.text.isEmpty) return;
    
    var domain = _urlController.text.trim();
    if (domain.startsWith('http://')) domain = domain.substring(7);
    if (domain.startsWith('https://')) domain = domain.substring(8);
    domain = domain.split('/')[0];
    
    final blocked = _bloomFilter!.contains(domain);
    
    setState(() {
      _isUrlBlocked = blocked;
    });

    if (blocked) {
      try {
        await ApiService.logBlockedDomain(widget.profileId, domain);
      } catch (e) {
        debugPrint('Erreur envoi log: $e');
      }
    }
  }

  // SOS: long press (3 seconds)
  void _startSosHold() {
    setState(() {
      _sosHoldProgress = 0.0;
    });
    _sosTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _sosHoldProgress += 50 / 3000; // 3 seconds total
      });
      if (_sosHoldProgress >= 1.0) {
        timer.cancel();
        _triggerSos();
      }
    });
  }

  void _cancelSosHold() {
    _sosTimer?.cancel();
    setState(() {
      _sosHoldProgress = 0.0;
    });
  }

  Future<void> _triggerSos() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isSosTriggered = true;
    });

    try {
      await ApiService.triggerSos(widget.profileId);
    } catch (_) {
      // Even if API fails, show confirmation
    }

    // Reset after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isSosTriggered = false;
          _sosHoldProgress = 0.0;
        });
      }
    });
  }

  Color _getTimerColor() {
    if (!_hasLimit) return const Color(0xFF2563EB); // Blue
    if (_minutesRemaining <= 0) return const Color(0xFFEF4444); // Red
    final ratio = _minutesRemaining / _dailyLimitMinutes;
    if (ratio <= 0.15) return const Color(0xFFEF4444); // Red
    if (ratio <= 0.35) return const Color(0xFFF97316); // Orange
    return const Color(0xFF10B981); // Green
  }

  String _formatTime(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_hasPin) {
            _showPinDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Action bloquée par FamilyGuard')),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white, // White background
        body: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)),
                )
              : (_isBedtimeBlocked || _isManuallyBlocked || (_hasLimit && _minutesRemaining <= 0))
                  ? _buildBedtimeScreen()
                  : _buildTimerScreen(),
        ),
      ),
    );
  }

  // ─── Bedtime Blocked Screen ───
  Widget _buildBedtimeScreen() {
    final bool isTimeUp = _hasLimit && _minutesRemaining <= 0;
    
    IconData getIcon() {
      if (_isManuallyBlocked) return Icons.lock_rounded;
      if (isTimeUp) return Icons.timer_off_rounded;
      return Icons.bedtime_rounded;
    }

    String getTitle() {
      if (_isManuallyBlocked) return 'Appareil Verrouillé 🔒';
      if (isTimeUp) return 'Temps écoulé !';
      return 'C\'est l\'heure de dormir ! 🌙';
    }

    String getSubtitle() {
      if (_isManuallyBlocked) return 'Cet appareil a été bloqué par vos parents.';
      return 'L\'appareil est en pause.';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            getIcon(), 
            size: 100, 
            color: const Color(0xFFF97316), // Orange warning
          ),
          const SizedBox(height: 24),
          Text(
            getTitle(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            getSubtitle(),
            style: const TextStyle(fontSize: 16, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 64),
          _buildSosButton(),
        ],
      ),
    );
  }

  // ─── Timer Screen ───
  Widget _buildTimerScreen() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour ${widget.profileName} 👋',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hasLimit ? 'Ton temps d\'écran aujourd\'hui' : 'Pas de limite configurée',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _isExamMode
                      ? const Color(0xFFF97316).withValues(alpha: 0.2)
                      : const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isExamMode ? Icons.school_rounded : Icons.circle,
                      size: _isExamMode ? 14 : 8,
                      color: _isExamMode ? const Color(0xFFF97316) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isExamMode ? 'Examen' : 'Actif',
                      style: TextStyle(
                        color: _isExamMode ? const Color(0xFFF97316) : const Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Exam mode banner
        if (_isExamMode)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: Color(0xFFF97316), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Examen actif 📝',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF97316),
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Seules ${_allowedApps.length} app(s) autorisée(s)',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Timer circle
        Expanded(
          child: Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _hasLimit && _minutesRemaining <= 15 ? _pulseAnimation.value : 1.0,
                  child: child,
                );
              },
              child: SizedBox(
                width: 280,
                height: 280,
                child: CustomPaint(
                  painter: _TimerPainter(
                    progress: _hasLimit && _dailyLimitMinutes > 0
                        ? _minutesRemaining / _dailyLimitMinutes
                        : 1.0,
                    color: _getTimerColor(),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _hasLimit ? _formatTime(_minutesRemaining) : '∞',
                          style: TextStyle(
                            fontSize: _hasLimit ? 48 : 64,
                            fontWeight: FontWeight.bold,
                            color: _getTimerColor(),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasLimit ? 'restant' : 'Temps libre',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                          ),
                        ),
                        if (_hasLimit) ...[
                          const SizedBox(height: 12),
                          Text(
                            '${_formatTime(_minutesUsed)} utilisé',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Simulator / Gamification row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RewardsScreen(profileId: widget.profileId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.stars, color: Colors.amber),
                      label: const Text('Récompenses', style: TextStyle(color: Colors.black87)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuestsScreen(profileId: widget.profileId, isParent: false),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment, color: Colors.blue),
                      label: const Text('Quêtes', style: TextStyle(color: Colors.black87)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _hasLimit && _minutesRemaining >= 5 ? _confirmDisconnectEarly : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Il faut au moins 5 minutes restantes pour gagner des points.')),
                    );
                  },
                  icon: const Icon(Icons.power_settings_new, color: Colors.white),
                  label: const Text('Déconnexion Anticipée', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasLimit && _minutesRemaining >= 5 ? const Color(0xFF10B981) : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Simulateur de Navigation (VPN test)
        _buildSimulatorCard(),

        // SOS Button
        Padding(
          padding: const EdgeInsets.only(bottom: 48, top: 24),
          child: _buildSosButton(),
        ),
      ],
    );
  }

  // ─── SOS Button ───
  Widget _buildSosButton() {
    if (_isSosTriggered) {
      return Column(
        children: [
          const Icon(Icons.check_circle, size: 64, color: Color(0xFF10B981)),
          const SizedBox(height: 12),
          const Text(
            'Alerte envoyée !',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tes parents ont été prévenus.',
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      );
    }

    return GestureDetector(
      onLongPressStart: (_) => _startSosHold(),
      onLongPressEnd: (_) => _cancelSosHold(),
      onLongPressCancel: _cancelSosHold,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              SizedBox(
                width: 88,
                height: 88,
                child: CircularProgressIndicator(
                  value: _sosHoldProgress,
                  strokeWidth: 4,
                  color: const Color(0xFFEF4444),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              // Button
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Maintenir 3 secondes pour alerter',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Simulator Card ───
  Widget _buildSimulatorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFF97316), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Simulateur VPN (Bloom Filter)',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_bloomFilter != null)
                const Icon(Icons.cloud_done, color: Color(0xFF10B981), size: 16)
              else
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Ex: malware.com',
                    hintStyle: const TextStyle(color: Colors.black38),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _bloomFilter != null ? _checkUrl : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Tester', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          if (_isUrlBlocked != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _isUrlBlocked! ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUrlBlocked! ? Icons.gpp_bad : Icons.gpp_good,
                    color: _isUrlBlocked! ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUrlBlocked! ? 'Domaine bloqué !' : 'Domaine autorisé',
                    style: TextStyle(
                      color: _isUrlBlocked! ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}

// ─── Custom Painter: Circular Timer ───

class _TimerPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color color;
  final Color backgroundColor;

  _TimerPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,          // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
