import 'package:flutter/material.dart';
import 'quiz_screen.dart';

class MiniGamesScreen extends StatelessWidget {
  final int profileId;

  const MiniGamesScreen({super.key, required this.profileId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Zone de Jeux 🎮', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.indigo.shade900,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entraîne ton cerveau !',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gagne des points de confiance en jouant à nos mini-jeux éducatifs.',
                style: TextStyle(fontSize: 16, color: Colors.indigo.shade400),
              ),
              const SizedBox(height: 30),
              
              // QCM Game Card
              _buildGameCard(
                context: context,
                title: 'Le Grand Quiz',
                subtitle: 'Culture générale, Sciences et Maths',
                icon: Icons.lightbulb_outline_rounded,
                color: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(profileId: profileId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Another Game Placeholder
              _buildGameCard(
                context: context,
                title: 'Calcul Mental',
                subtitle: 'Bientôt disponible',
                icon: Icons.calculate_outlined,
                color: Colors.green,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bientôt disponible !')),
                  );
                },
                isLocked: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required MaterialColor color,
    required VoidCallback onTap,
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: color.shade800),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isLocked ? Colors.grey : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isLocked)
                Icon(Icons.lock_outline, color: Colors.grey.shade400)
              else
                Icon(Icons.arrow_forward_ios, color: color.shade300, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
