import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ParentQuizManagementScreen extends StatefulWidget {
  final int profileId;
  const ParentQuizManagementScreen({super.key, required this.profileId});

  @override
  State<ParentQuizManagementScreen> createState() => _ParentQuizManagementScreenState();
}

class _ParentQuizManagementScreenState extends State<ParentQuizManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await ApiService.getCustomQuizQuestions(widget.profileId);
      setState(() {
        _questions = questions;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteQuestion(int id) async {
    try {
      await ApiService.deleteCustomQuizQuestion(widget.profileId, id);
      _loadQuestions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    String category = 'Famille';
    String question = '';
    List<String> options = ['', '', '', ''];
    int correctIndex = 0;
    int points = 10;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Nouvelle question', style: TextStyle(color: SafeChildColors.primary)),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Catégorie'),
                        initialValue: category,
                        onSaved: (val) => category = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                      ),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Question'),
                        onSaved: (val) => question = val ?? '',
                        validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 16),
                      const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                      RadioGroup<int>(
                        groupValue: correctIndex,
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => correctIndex = val);
                          }
                        },
                        child: Column(
                          children: List.generate(4, (i) {
                            return Row(
                              children: [
                                Radio<int>(
                                  value: i,
                                ),
                                Expanded(
                                  child: TextFormField(
                                    decoration: InputDecoration(hintText: 'Option ${i + 1}'),
                                    onSaved: (val) => options[i] = val ?? '',
                                    validator: (val) => val == null || val.isEmpty ? 'Requis' : null,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Points'),
                        initialValue: '10',
                        keyboardType: TextInputType.number,
                        onSaved: (val) => points = int.tryParse(val ?? '10') ?? 10,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(ctx);
                      try {
                        await ApiService.addCustomQuizQuestion(widget.profileId, {
                          'category': category,
                          'question': question,
                          'options': options,
                          'correct_index': correctIndex,
                          'points': points,
                        });
                        if (mounted) {
                          _loadQuestions();
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: SafeChildColors.primary),
                  child: const Text('Ajouter'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SafeChildColors.background,
      appBar: AppBar(
        title: const Text('Questions Personnalisées'),
        backgroundColor: Colors.white,
        foregroundColor: SafeChildColors.textMain,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.quiz_outlined, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text('Aucune question personnalisée.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    final q = _questions[index];
                    final options = q['options'] as List<dynamic>;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Chip(
                                  label: Text(q['category'], style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  backgroundColor: SafeChildColors.primary,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: SafeChildColors.danger),
                                  onPressed: () => _deleteQuestion(q['id']),
                                )
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(q['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            ...List.generate(options.length, (i) {
                              bool isCorrect = i == q['correct_index'];
                              return Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  color: isCorrect ? SafeChildColors.success.withValues(alpha: 0.1) : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isCorrect ? SafeChildColors.success : Colors.transparent),
                                ),
                                child: Row(
                                  children: [
                                    if (isCorrect) const Icon(Icons.check_circle, color: SafeChildColors.success, size: 16),
                                    if (isCorrect) const SizedBox(width: 8),
                                    Text(options[i]),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        backgroundColor: SafeChildColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
