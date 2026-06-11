import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RewardsScreen extends StatefulWidget {
  final int profileId;

  const RewardsScreen({super.key, required this.profileId});

  @override
  RewardsScreenState createState() => RewardsScreenState();
}

class RewardsScreenState extends State<RewardsScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _summary;
  List<dynamic> _rewards = [];
  String _errorMessage = '';

  late AnimationController _avatarController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _avatarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.elasticOut)
    );

    _loadData();
  }

  @override
  void dispose() {
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await ApiService.getGamificationSummary(widget.profileId);
      final rewards = await ApiService.getRewards(widget.profileId);

      setState(() {
        _summary = summary;
        _rewards = rewards;
        _isLoading = false;
      });
      _avatarController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _claimReward(int rewardId, int cost) async {
    final currentPoints = _summary?['total_points'] ?? 0;
    if (currentPoints < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Points insuffisants !'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await ApiService.claimReward(widget.profileId, rewardId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Récompense réclamée ! 🎉'), backgroundColor: Colors.green),
      );
      _loadData(); // Refresh to deduct points and update UI
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  String _getAvatarEmoji(int level) {
    switch (level) {
      case 1: return '🐣';
      case 2: return '🐥';
      case 3: return '🐤';
      case 4: return '🦅';
      case 5: return '🦉';
      default: return '🦉';
    }
  }

  String _getLevelName(int level) {
    switch (level) {
      case 1: return 'Œuf Curieux';
      case 2: return 'Oisillon Actif';
      case 3: return 'Petit Oiseau Volant';
      case 4: return 'Aigle Protecteur';
      case 5: return 'Hibou Sage';
      default: return 'Légende';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Récompenses')),
        body: Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
      );
    }

    final totalPoints = _summary?['total_points'] ?? 0;
    final level = _summary?['avatar_level'] ?? 1;
    final currentStreak = _summary?['current_streak'] ?? 0;
    final bestStreak = _summary?['best_streak'] ?? 0;
    final badges = _summary?['recent_badges'] as List<dynamic>? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Mes Récompenses', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: Avatar & Points ──
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 3),
                        ),
                        child: Text(
                          _getAvatarEmoji(level),
                          style: const TextStyle(fontSize: 64),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getLevelName(level),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 28),
                        const SizedBox(width: 8),
                        Text(
                          '$totalPoints pts',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Streaks & Badges ──
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Série',
                      '🔥 $currentStreak jours',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Record',
                      '🏆 $bestStreak jours',
                      Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (badges.isNotEmpty) ...[
                const Text('Derniers Badges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: badges.length,
                    itemBuilder: (context, index) {
                      final badge = badges[index];
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(badge['icon_emoji'], style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 8),
                            Text(
                              badge['name'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── Rewards List ──
              const Text('Récompenses Disponibles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_rewards.isEmpty)
                const Text('Aucune récompense pour le moment. Demande à tes parents !', 
                  style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ..._rewards.map((reward) {
                final isClaimed = reward['is_claimed'];
                final cost = reward['point_cost'];
                final canAfford = totalPoints >= cost;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isClaimed ? Colors.grey.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      reward['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: isClaimed ? TextDecoration.lineThrough : null,
                        color: isClaimed ? Colors.grey : Colors.black,
                      ),
                    ),
                    subtitle: reward['description'] != null
                        ? Text(reward['description'])
                        : null,
                    trailing: isClaimed
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 32)
                        : ElevatedButton(
                            onPressed: canAfford ? () => _claimReward(reward['id'], cost) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford ? const Color(0xFF10B981) : Colors.grey[300],
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: Text('$cost pts', style: TextStyle(color: canAfford ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold)),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color[700])),
        ],
      ),
    );
  }
}
