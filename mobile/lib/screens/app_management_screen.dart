import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class AppManagementScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const AppManagementScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  AppManagementScreenState createState() => AppManagementScreenState();
}

class AppManagementScreenState extends State<AppManagementScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  List<dynamic> _appUsage = [];
  List<String> _blockedApps = [];
  
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 1. Load app usage detail
      final usage = await ApiService.getAppUsageDetail(widget.profileId);
      
      // 2. Load time rules to find blocked apps
      final token = await ApiService.getToken();
      if (token == null) return;
      
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/profiles/${widget.profileId}/time-rules'),
        headers: {'Authorization': 'Bearer $token'},
      );

      List<String> currentBlockedApps = [];
      if (response.statusCode == 200) {
        final rules = jsonDecode(response.body) as List;
        for (var r in rules) {
          if (r['rule_type'] == 'APP_BLOCK') {
            if (r['blocked_apps'] != null) {
              currentBlockedApps = List<String>.from(r['blocked_apps']);
            }
          }
        }
      }

      setState(() {
        _appUsage = usage;
        _blockedApps = currentBlockedApps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des données.';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAppBlock(String packageName, bool isBlocked) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      List<String> newBlockedApps = List.from(_blockedApps);
      if (isBlocked) {
        if (!newBlockedApps.contains(packageName)) {
          newBlockedApps.add(packageName);
        }
      } else {
        newBlockedApps.remove(packageName);
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/profiles/${widget.profileId}/time-rules'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'rule_type': 'APP_BLOCK',
          'blocked_apps': newBlockedApps,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          _blockedApps = newBlockedApps;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isBlocked ? 'Application bloquée' : 'Application débloquée'),
              backgroundColor: isBlocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Erreur serveur');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la mise à jour.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Temps d\'écran · ${widget.profileName}', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Utilisation par application',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Aujourd\'hui',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_appUsage.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'Aucune donnée d\'utilisation pour aujourd\'hui.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      else
                        ..._appUsage.map((app) {
                          final isBlocked = _blockedApps.contains(app['package_name']);
                          final maxMinutes = _appUsage.first['minutes_today'] as int;
                          final currentMinutes = app['minutes_today'] as int;
                          final progress = maxMinutes > 0 ? currentMinutes / maxMinutes : 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          app['icon'],
                                          style: const TextStyle(fontSize: 24),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            app['app_name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          Text(
                                            app['category'],
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _formatMinutes(currentMinutes),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                        Switch(
                                          value: !isBlocked,
                                          onChanged: (val) {
                                            _toggleAppBlock(app['package_name'], !val);
                                          },
                                          activeThumbColor: const Color(0xFF10B981),
                                          inactiveThumbColor: const Color(0xFFEF4444),
                                          inactiveTrackColor: const Color(0xFFEF4444).withValues(alpha: 0.3),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  color: isBlocked ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                                  borderRadius: BorderRadius.circular(4),
                                  minHeight: 6,
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
