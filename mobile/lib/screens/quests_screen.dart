import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadQuests();
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
        title: const Text('Mes Quêtes 🏆'),
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
      statusColor = Colors.orange;
      statusText = 'En attente de validation';
    } else if (status == 'VALIDATED') {
      statusColor = Colors.green;
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
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${quest['points_reward']} pts',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text('Terminer'),
                  ),
                if (widget.isParent && status == 'COMPLETED_BY_CHILD')
                  ElevatedButton(
                    onPressed: () => _validateQuest(quest['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
