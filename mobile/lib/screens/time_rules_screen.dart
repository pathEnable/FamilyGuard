import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';

class TimeRulesScreen extends StatefulWidget {
  final int profileId;
  final String profileName;

  const TimeRulesScreen({
    super.key,
    required this.profileId,
    required this.profileName,
  });

  @override
  TimeRulesScreenState createState() => TimeRulesScreenState();
}

class TimeRulesScreenState extends State<TimeRulesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  // Daily limit
  bool _hasDailyLimit = false;
  double _limitHours = 2.0;

  // Bedtime
  bool _hasBedtime = false;
  TimeOfDay _bedtimeStart = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _bedtimeEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    final box = Hive.box('time_rules');
    try {
      final token = await ApiService.getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/profiles/${widget.profileId}/time-rules'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final rules = jsonDecode(response.body) as List;
        
        // Cache rules offline
        box.put('rules_${widget.profileId}', rules);

        _applyRulesToState(rules);
      }
    } catch (e) {
      // Offline fallback
      final cachedRules = box.get('rules_${widget.profileId}');
      if (cachedRules != null) {
        _applyRulesToState(cachedRules);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mode hors-ligne : affichage des règles en cache'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _errorMessage = 'Impossible de charger les règles');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyRulesToState(List rules) {
    for (final rule in rules) {
      if (rule['rule_type'] == 'daily_limit') {
        setState(() {
          _hasDailyLimit = true;
          _limitHours = ((rule['daily_limit_minutes'] as int) / 60.0).clamp(0.5, 12.0);
        });
      }
      if (rule['rule_type'] == 'bedtime') {
        final startParts = (rule['bedtime_start'] as String).split(':');
        final endParts = (rule['bedtime_end'] as String).split(':');
        setState(() {
          _hasBedtime = true;
          _bedtimeStart = TimeOfDay(
            hour: int.parse(startParts[0]),
            minute: int.parse(startParts[1]),
          );
          _bedtimeEnd = TimeOfDay(
            hour: int.parse(endParts[0]),
            minute: int.parse(endParts[1]),
          );
        });
      }
    }
  }

  Future<void> _saveRules() async {
    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    try {
      final token = await ApiService.getToken();
      if (token == null) throw Exception('Non autorisé');

      // Save or delete daily limit rule
      if (_hasDailyLimit) {
        await http.post(
          Uri.parse('${ApiService.baseUrl}/profiles/${widget.profileId}/time-rules'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'rule_type': 'daily_limit',
            'daily_limit_minutes': (_limitHours * 60).round(),
          }),
        );
      }

      // Save bedtime rule
      if (_hasBedtime) {
        String formatTime(TimeOfDay t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
        await http.post(
          Uri.parse('${ApiService.baseUrl}/profiles/${widget.profileId}/time-rules'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'rule_type': 'bedtime',
            'bedtime_start': formatTime(_bedtimeStart),
            'bedtime_end': formatTime(_bedtimeEnd),
          }),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Règles sauvegardées ✓'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _errorMessage = 'Erreur lors de la sauvegarde');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _bedtimeStart : _bedtimeEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _bedtimeStart = picked;
        } else {
          _bedtimeEnd = picked;
        }
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Règles · ${widget.profileName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFEF4444)),
                      ),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Color(0xFFEF4444)),
                      ),
                    ),

                  // ─── Daily Limit Card ───
                  _buildCard(
                    icon: Icons.timer_outlined,
                    iconColor: const Color(0xFF2563EB),
                    title: 'Limite quotidienne',
                    subtitle: 'Durée maximale d\'écran par jour',
                    toggle: Switch(
                      value: _hasDailyLimit,
                      activeTrackColor: const Color(0xFF2563EB).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (v) => setState(() => _hasDailyLimit = v),
                    ),
                    children: _hasDailyLimit
                        ? [
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Limite : ${_limitHours.toStringAsFixed(1)}h',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                Text(
                                  '(${(_limitHours * 60).round()} min)',
                                  style: const TextStyle(color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            Slider(
                              value: _limitHours,
                              min: 0.5,
                              max: 12.0,
                              divisions: 23,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _limitHours = v),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('30 min', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                                const Text('12h', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ],
                            ),
                          ]
                        : [],
                  ),

                  const SizedBox(height: 16),

                  // ─── Bedtime Card ───
                  _buildCard(
                    icon: Icons.bedtime_outlined,
                    iconColor: const Color(0xFFF97316),
                    title: 'Couvre-feu',
                    subtitle: 'Bloquer l\'appareil la nuit',
                    toggle: Switch(
                      value: _hasBedtime,
                      activeTrackColor: const Color(0xFFF97316).withValues(alpha: 0.5),
                      activeThumbColor: const Color(0xFFF97316),
                      onChanged: (v) => setState(() => _hasBedtime = v),
                    ),
                    children: _hasBedtime
                        ? [
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTimePicker(
                                    label: 'Début',
                                    time: _bedtimeStart,
                                    onTap: () => _pickTime(true),
                                    color: const Color(0xFFF97316),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Icon(Icons.arrow_forward, color: Color(0xFF94A3B8)),
                                ),
                                Expanded(
                                  child: _buildTimePicker(
                                    label: 'Fin',
                                    time: _bedtimeEnd,
                                    onTap: () => _pickTime(false),
                                    color: const Color(0xFFF97316),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFF97316)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'L\'appareil sera bloqué de ${_formatTimeOfDay(_bedtimeStart)} à ${_formatTimeOfDay(_bedtimeEnd)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFF97316),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : [],
                  ),

                  const SizedBox(height: 40),

                  // Save button
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveRules,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Sauvegarder', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget toggle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              toggle,
            ],
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimeOfDay(time),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
