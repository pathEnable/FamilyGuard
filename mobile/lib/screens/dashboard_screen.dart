import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'child_dashboard_screen.dart';
import 'add_profile_screen.dart';
import 'edit_profile_screen.dart';
import 'time_rules_screen.dart';
import 'logs_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<dynamic> _profiles = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await ApiService.getProfiles();
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    } catch (e) {
      if (e.toString().contains('Non autorisé')) {
        _logout();
      } else {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    // Assuming authProvider is imported or available, but we can just use ApiService here
    // as it's a minimal refactor.
    await ApiService.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showSetPinDialog(int profileId, String profileName) async {
    final pinController = TextEditingController();
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('PIN pour $profileName', style: const TextStyle(fontSize: 18))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ce code (4 à 6 chiffres) sera demandé pour quitter l\'interface enfant.',
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
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler', style: TextStyle(color: Colors.black54)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    if (pin.length < 4) {
                      setDialogState(() => errorText = '4 chiffres minimum');
                      return;
                    }
                    try {
                      await ApiService.setPin(profileId, pin);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code PIN enregistré avec succès')),
                      );
                    } catch (e) {
                      setDialogState(() => errorText = 'Erreur lors de la sauvegarde');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleLock(int profileId, bool currentLockedState) async {
    try {
      await ApiService.toggleLock(profileId, !currentLockedState);
      _loadProfiles(); // Reload to update UI
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du verrouillage')),
        );
      }
    }
  }

  Future<void> _showWeeklyChart(int profileId, String profileName) async {
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: ApiService.getWeeklyUsage(profileId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return const SizedBox(
                height: 300,
                child: Center(child: Text('Erreur de chargement')),
              );
            }

            final data = snapshot.data ?? [];
            if (data.isEmpty) {
              return const SizedBox(
                height: 300,
                child: Center(child: Text('Aucune donnée disponible')),
              );
            }

            // Find max minutes to scale the bars
            int maxMins = 60; // Minimum scale of 1 hour
            for (var d in data) {
              final m = (d['minutes'] ?? 0) as int;
              if (m > maxMins) maxMins = m;
            }

            return Container(
              padding: const EdgeInsets.all(24),
              height: 350,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Temps d\'écran (7 jours)',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.map((dayData) {
                        final mins = (dayData['minutes'] ?? 0) as int;
                        final double percentage = (mins / maxMins).clamp(0.0, 1.0);
                        final hours = mins ~/ 60;
                        final remainingMins = mins % 60;
                        final timeStr = '${hours}h${remainingMins.toString().padLeft(2, '0')}';

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 10, color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              width: 30,
                              height: 150 * percentage + 4, // min height of 4
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dayData['day'] ?? '',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vos Enfants', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2563EB),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white),
            tooltip: 'Historique',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Déconnexion',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Color(0xFFEF4444)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _profiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.child_care, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun profil enfant',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Créez un profil pour commencer.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _profiles.length,
                      itemBuilder: (context, index) {
                        final profile = _profiles[index];
                        final bool isActive = profile['is_active'] ?? false;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFDBEAFE),
                              foregroundColor: const Color(0xFF2563EB),
                              radius: 28,
                              child: Text(
                                profile['name'][0].toString().toUpperCase(),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              profile['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('${profile['age']} ans'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isActive ? 'Actif' : 'Inactif',
                                      style: TextStyle(
                                        color: isActive ? const Color(0xFF10B981) : Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    (profile['is_locked'] ?? false) ? Icons.lock : Icons.lock_open,
                                    color: (profile['is_locked'] ?? false) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                  ),
                                  tooltip: 'Verrouiller/Déverrouiller',
                                  onPressed: () {
                                    _toggleLock(profile['id'], profile['is_locked'] ?? false);
                                  },
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'edit':
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => EditProfileScreen(profile: profile),
                                          ),
                                        );
                                        if (result != null) _loadProfiles();
                                        break;
                                      case 'chart':
                                        _showWeeklyChart(profile['id'], profile['name']);
                                        break;
                                      case 'pin':
                                        _showSetPinDialog(profile['id'], profile['name']);
                                        break;
                                      case 'time':
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => TimeRulesScreen(
                                              profileId: profile['id'],
                                              profileName: profile['name'],
                                            ),
                                          ),
                                        );
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded, color: Color(0xFF3B82F6)), title: Text('Modifier'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'chart', child: ListTile(leading: Icon(Icons.bar_chart_rounded, color: Color(0xFF64748B)), title: Text('Temps d\'écran'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'pin', child: ListTile(leading: Icon(Icons.pin, color: Color(0xFF64748B)), title: Text('Code PIN'), dense: true, contentPadding: EdgeInsets.zero)),
                                    const PopupMenuItem(value: 'time', child: ListTile(leading: Icon(Icons.timer_outlined, color: Color(0xFF64748B)), title: Text('Règles de temps'), dense: true, contentPadding: EdgeInsets.zero)),
                                  ],
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChildDashboardScreen(
                                    profileId: profile['id'],
                                    profileName: profile['name'],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddProfileScreen()),
          );
          if (result == true) {
            _loadProfiles(); // Reload profiles if a new one was added
          }
        },
        backgroundColor: const Color(0xFF2563EB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
