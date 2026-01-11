import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/civics_question_model.dart';
import '../../services/stats_service.dart'; // Import Service

class QuizViewModel extends ChangeNotifier {
  List<CivicsQuestion> _fullQuestionBank = [];
  List<CivicsQuestion> _quizQuestions = [];
  
  // Storage for options so they don't reshuffle on every notify
  final Map<String, List<String>> _optionsMap = {}; 
  
  int _currentQuestionIndex = 0;
  int _score = 0;
  String? _selectedAnswer;
  bool _isAnswered = false;
  bool _isLoading = true;

  // Getters
  int get currentQuestionIndex => _currentQuestionIndex;
  int get totalQuestions => _quizQuestions.length;
  int get score => _score;
  String? get selectedAnswer => _selectedAnswer;
  bool get isAnswered => _isAnswered;
  bool get isLoading => _isLoading;

  Map<String, dynamic> get currentQuestion {
    if (_quizQuestions.isEmpty) return {};
    final q = _quizQuestions[_currentQuestionIndex];
    
    return {
      'question': q.questionText,
      'answer': q.acceptableAnswers.isNotEmpty ? q.acceptableAnswers.first : '',
      'options': _optionsMap[q.id] ?? [],
    };
  }

  QuizViewModel() {
    _loadQuizData();
  }

  Future<void> _loadQuizData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Default to 2025 if not set (true)
      final bool is2025 = prefs.getBool('is_2025_version') ?? true;
      final String assetPath = is2025 
          ? 'assets/civics_questions_2025.json' 
          : 'assets/civics_questions_2008.json';

      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> data = json.decode(response);
      
      _fullQuestionBank = data.map((json) => CivicsQuestion.fromJson(json)).toList();
      
      await _startNewQuiz();
    } catch (e) {
      debugPrint('Error loading quiz data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _startNewQuiz() async {
    if (_fullQuestionBank.isEmpty) return;
    
    _isLoading = true;
    // notifyListeners(); // Optional: don't flicker if already loading

    // 1. Load Seen IDs based on version
    final prefs = await SharedPreferences.getInstance();
    final bool is2025 = prefs.getBool('is_2025_version') ?? true;
    final String seenKey = is2025 ? 'quiz_seen_ids' : 'quiz_seen_ids_2008';

    List<String> seenIds = prefs.getStringList(seenKey) ?? [];
    
    // 2. Determine Unseen
    List<CivicsQuestion> unseen = _fullQuestionBank.where((q) => !seenIds.contains(q.id)).toList();
    
    List<CivicsQuestion> selected = [];
    final random = Random();
    
    // 3. Selection Logic (Deck behavior)
    if (unseen.length >= 20) {
      // Plenty of unseen questions
      unseen.shuffle(random);
      selected = unseen.take(20).toList();
    } else {
      // Not enough unseen. Take all remaining unseen, then reset and fill.
      selected.addAll(unseen); // Add the last few
      
      int needed = 20 - unseen.length;
      
      // Reset Deck
      seenIds.clear(); 
      List<CivicsQuestion> freshDeck = List.from(_fullQuestionBank);
      freshDeck.removeWhere((q) => selected.contains(q)); // Don't pick the ones we just picked
      freshDeck.shuffle(random);
      
      selected.addAll(freshDeck.take(needed));
    }
    
    _quizQuestions = selected;

    // 4. Update Seen IDs
    Set<String> newSeenSet = seenIds.toSet();
    for (var q in _quizQuestions) {
      newSeenSet.add(q.id);
    }
    await prefs.setStringList(seenKey, newSeenSet.toList());

    // 5. Generate Options
    _optionsMap.clear();
    for (var q in _quizQuestions) {
      _optionsMap[q.id] = _generateOptionsFor(q, _fullQuestionBank);
    }

    _currentQuestionIndex = 0;
    _score = 0;
    _selectedAnswer = null;
    _isAnswered = false;
    _isLoading = false;
    
    notifyListeners();
  }

  // Generate A, B, C, D (1 Correct + 3 Random Distractors)
  List<String> _generateOptionsFor(CivicsQuestion correctQ, List<CivicsQuestion> allQuestions) {
    if (correctQ.acceptableAnswers.isEmpty) return ["Error"];
    
    final correctAnswer = correctQ.acceptableAnswers.first;
    final Set<String> options = {correctAnswer};
    final random = Random();

    // Attempt to add 3 unique distractors
    int attempts = 0;
    while (options.length < 4 && attempts < 100) {
      final randomQ = allQuestions[random.nextInt(allQuestions.length)];
      if (randomQ.id != correctQ.id && randomQ.acceptableAnswers.isNotEmpty) {
        options.add(randomQ.acceptableAnswers.first);
      }
      attempts++;
    }

    // Convert to list and shuffle
    final optionsList = options.toList();
    optionsList.shuffle(random);
    return optionsList;
  }

  // Logic: Handle Answer Selection
  void answerQuestion(String answer) {
    if (_isAnswered) return; 
    
    // Safety check just in case
    if (_quizQuestions.isEmpty || _currentQuestionIndex >= _quizQuestions.length) return;

    _selectedAnswer = answer;
    _isAnswered = true;

    final currentQ = _quizQuestions[_currentQuestionIndex];
    
    // Simple string match check
    if (answer == currentQuestion['answer']) {
      _score++;
      // If they get it right, remove from incorrect list (remedial logic)
      StatsService.removeIncorrect(currentQ.id);
    } else {
      // If wrong, add to incorrect list
      StatsService.addIncorrect(currentQ.id);
    }

    notifyListeners();
  }

  // Logic: Next Question
  void nextQuestion(BuildContext context) {
    if (_currentQuestionIndex < _quizQuestions.length - 1) {
      _currentQuestionIndex++;
      _selectedAnswer = null;
      _isAnswered = false;
      notifyListeners();
    } else {
      _finishQuiz(context);
    }
  }

  Future<void> _finishQuiz(BuildContext context) async {
    // SAVE STATS
    await StatsService.saveResult(_score, 20);

    if (!context.mounted) return;

    final passed = _score >= 12;
    final title = passed ? "Congratulations!" : "Keep Practicing";
    final msg = passed 
        ? "You passed with $_score/20!" 
        : "You scored $_score/20. You need 12 to pass.";
    final color = passed ? Colors.green : Colors.orange;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Exit Quiz Screen
            },
            child: const Text("Exit"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF112D50)),
            onPressed: () {
              Navigator.pop(context);
              _startNewQuiz();
            },
            child: const Text("Try Again", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void resetQuiz() {
    _startNewQuiz();
  }
}
