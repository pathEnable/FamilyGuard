import 'package:flutter/material.dart';
import 'dart:async';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';

class QuizScreen extends StatefulWidget {
  final int profileId;

  const QuizScreen({super.key, required this.profileId});

  @override
  QuizScreenState createState() => QuizScreenState();
}

class QuizScreenState extends State<QuizScreen> {
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  String? _error;

  int _pointsEarned = 0;
  
  // State for the current question
  int? _selectedIndex;
  bool _isAnswerRevealed = false;
  int? _correctIndex;
  
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadQuestions();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final questions = await ApiService.getQuizQuestions(widget.profileId, limit: 5);
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submitAnswer(int index) async {
    if (_isAnswerRevealed) return; // Prevent double taps

    setState(() {
      _selectedIndex = index;
      _isAnswerRevealed = true;
    });

    try {
      final questionId = _questions[_currentIndex]['id'];
      final result = await ApiService.submitQuizAnswer(widget.profileId, questionId, index);
      
      final bool isCorrect = result['is_correct'] ?? false;
      final int correctIdx = result['correct_index'] ?? 0;
      final int points = result['points_earned'] ?? 0;

      setState(() {
        _correctIndex = correctIdx;
        _pointsEarned += points;
      });

      if (isCorrect) {
        _confettiController.play();
      }

      // Wait a bit before moving to the next question
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        if (_currentIndex < _questions.length - 1) {
          setState(() {
            _currentIndex++;
            _selectedIndex = null;
            _isAnswerRevealed = false;
            _correctIndex = null;
          });
        } else {
          _showResultsDialog();
        }
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
      // Reset so they can try again or skip
      setState(() {
        _selectedIndex = null;
        _isAnswerRevealed = false;
      });
    }
  }

  void _showResultsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quiz Terminé ! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Super travail ! Tu as gagné :'),
            const SizedBox(height: 16),
            Text(
              '+$_pointsEarned points',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // close quiz screen
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text('Génial !'),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      appBar: AppBar(
        title: const Text('Le Grand Quiz'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.indigo.shade900,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _questions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.celebration, size: 80, color: Colors.indigo.shade200),
                                const SizedBox(height: 16),
                                const Text('Plus de questions pour le moment !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text('Reviens demain pour de nouvelles questions.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : _buildQuizContent(),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final currentQ = _questions[_currentIndex];
    final List<dynamic> options = currentQ['options'];

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_currentIndex + 1} / ${_questions.length}',
                style: TextStyle(color: Colors.indigo.shade400, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${currentQ['category']}',
                  style: TextStyle(color: Colors.amber.shade800, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.indigo.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          const SizedBox(height: 40),
          
          // Question text
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Text(
              currentQ['question'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          
          // Options
          Expanded(
            child: ListView.separated(
              itemCount: options.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                
                Color bgColor = Colors.white;
                Color borderColor = Colors.indigo.shade100;
                Color textColor = Colors.indigo.shade900;

                if (_isAnswerRevealed) {
                  if (index == _correctIndex) {
                    bgColor = Colors.green.shade50;
                    borderColor = Colors.green;
                    textColor = Colors.green.shade800;
                  } else if (isSelected) {
                    bgColor = Colors.red.shade50;
                    borderColor = Colors.red;
                    textColor = Colors.red.shade800;
                  }
                } else if (isSelected) {
                  bgColor = Colors.indigo.shade50;
                  borderColor = Colors.indigo;
                }

                return GestureDetector(
                  onTap: () => _submitAnswer(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [
                        if (!isSelected && !_isAnswerRevealed)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${String.fromCharCode(65 + index)}.', // A, B, C, D
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            options[index],
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (_isAnswerRevealed && index == _correctIndex)
                          const Icon(Icons.check_circle, color: Colors.green)
                        else if (_isAnswerRevealed && isSelected)
                          const Icon(Icons.cancel, color: Colors.red),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
