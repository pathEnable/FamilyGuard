import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../theme.dart';
import 'dart:async';

class QuestsScreen extends StatefulWidget {
  final int profileId;
  final bool isParent;

  const QuestsScreen({super.key, required this.profileId, required this.isParent});

  @override
  QuestsScreenState createState() => QuestsScreenState();
}

class QuestsScreenState extends State<QuestsScreen> {
  List<dynamic> quests = [];
  bool isLoading = true;
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadQuests();
    
    _wsSubscription = WebSocketService.instance.messages.listen((msg) {
      if (msg['type'] == 'gamification_updated' && msg['profile_id'] == widget.profileId) {
        _loadQuests();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadQuests() async {
    setState(() => isLoading = true);
    try {
      final fetchedQuests = await ApiService.getQuests(widget.profileId);
      setState(() {
        quests = fetchedQuests;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _completeQuest(int questId) async {
    try {
      await ApiService.completeQuest(questId);
      _loadQuests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quête marquée comme terminée ! En attente du parent.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _validateQuest(int questId) async {
    try {
      await ApiService.validateQuest(questId);
      _loadQuests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quête validée, points accordés !')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Quêtes 🏆', style: TextStyle(color: Colors.white)),
        backgroundColor: SafeChildColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : quests.isEmpty
              ? const Center(child: Text("Aucune quête pour le moment."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: quests.length,
                  itemBuilder: (context, index) {
                    final quest = quests[index];
                    return _buildQuestCard(quest);
                  },
                ),
    );
  }

  Widget _buildQuestCard(dynamic quest) {
    final status = quest['status'];
    Color statusColor = Colors.grey;
    String statusText = 'En cours';

    if (status == 'COMPLETED_BY_CHILD') {
      statusColor = SafeChildColors.warning;
      statusText = 'En attente de validation';
    } else if (status == 'VALIDATED') {
      statusColor = SafeChildColors.success;
      statusText = 'Validée';
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    quest['title'],
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: SafeChildColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${quest['points_reward']} pts',
                    style: const TextStyle(color: SafeChildColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (quest['description'] != null && quest['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(quest['description'], style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: statusColor),
                    const SizedBox(width: 8),
                    Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
                  ],
                ),
                if (!widget.isParent && status == 'PENDING')
                  ElevatedButton(
                    onPressed: () => _completeQuest(quest['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SafeChildColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Terminer'),
                  ),
                if (widget.isParent && status == 'COMPLETED_BY_CHILD')
                  ElevatedButton(
                    onPressed: () => _validateQuest(quest['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SafeChildColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Valider'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
