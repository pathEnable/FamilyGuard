import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';

class WebFilteringScreen extends StatefulWidget {
  final int profileId;

  const WebFilteringScreen({super.key, required this.profileId});

  @override
  WebFilteringScreenState createState() => WebFilteringScreenState();
}

class WebFilteringScreenState extends State<WebFilteringScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _strictMode = false;
  List<dynamic> _whitelist = [];
  List<dynamic> _blacklist = [];

  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFilters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadFilters() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getWebFilters(widget.profileId);
      final rules = List<dynamic>.from(data['rules'] ?? []);
      
      if (mounted) {
        setState(() {
          _strictMode = data['strict_mode'] ?? false;
          _whitelist = rules.where((r) => r['rule_type'] == 'WHITELIST').toList();
          _blacklist = rules.where((r) => r['rule_type'] == 'BLACKLIST').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _toggleStrictMode(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.toggleStrictMode(widget.profileId, value);
      if (mounted) {
        setState(() {
          _strictMode = value;
        });
        messenger.showSnackBar(
          SnackBar(content: Text('Mode strict ${value ? "activé" : "désactivé"}')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _addRule(String ruleType) async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.addWebFilterRule(widget.profileId, url, ruleType);
      _urlController.clear();
      await _loadFilters();
      
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Règle ajoutée')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _deleteRule(int ruleId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.deleteWebFilterRule(widget.profileId, ruleId);
      await _loadFilters();
      
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Règle supprimée')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Widget _buildRulesList(List<dynamic> rules) {
    if (rules.isEmpty) {
      return const Center(
        child: Text(
          'Aucune règle',
          style: TextStyle(color: SafeChildColors.textMuted),
        ),
      );
    }

    return ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(
              Icons.language,
              color: rule['rule_type'] == 'WHITELIST' ? SafeChildColors.success : SafeChildColors.danger,
            ),
            title: Text(rule['url_pattern']),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: SafeChildColors.danger),
              onPressed: () => _deleteRule(rule['id']),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtrage Web'),
        backgroundColor: SafeChildColors.primary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Liste Blanche'),
            Tab(text: 'Liste Noire'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: SafeChildColors.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mode Strict',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: SafeChildColors.textMain,
                            ),
                          ),
                          const Text(
                            'Bloquer tout sauf la liste blanche',
                            style: TextStyle(
                              fontSize: 12,
                              color: SafeChildColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _strictMode,
                        activeThumbColor: SafeChildColors.primary,
                        onChanged: _toggleStrictMode,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Ex: wikipedia.org',
                            filled: true,
                            fillColor: SafeChildColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final type = _tabController.index == 0 ? 'WHITELIST' : 'BLACKLIST';
                          _addRule(type);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SafeChildColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRulesList(_whitelist),
                      _buildRulesList(_blacklist),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
