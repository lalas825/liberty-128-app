import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/civics_question_model.dart';
import '../../data/seeds/questions_2025_seed.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/stats_service.dart'; // Import Service

class VoicePracticeScreen extends StatefulWidget {
  const VoicePracticeScreen({super.key});

  @override
  State<VoicePracticeScreen> createState() => _VoicePracticeScreenState();
}

class _VoicePracticeScreenState extends State<VoicePracticeScreen> {
  // Tools
  late stt.SpeechToText _speech;
  
  // Data State
  List<CivicsQuestion> _questions = [];
  CivicsQuestion? _currentQuestion;
  bool _isLoading = true;
  
  // Voice State
  bool _isListening = false;
  bool _speechEnabled = false;
  String _userSpokenText = "Press the mic and speak...";
  String _feedbackMessage = "";
  Color _feedbackColor = Colors.grey;
  String _errorMessage = ""; 

  // Session State
  int _score = 0;
  int _questionIndex = 0;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _loadData();
  }

  // 1. Initialize Speech & Request Permissions
  void _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('onStatus: $status'),
        onError: (errorNotification) => print('onError: $errorNotification'),
      );
      if (mounted) {
        setState(() {
          _speechEnabled = available;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _userSpokenText = "Microphone permission denied.";
        });
      }
    }
  }

  // 2. Load the Civics Data (Random 20 with Deck Logic)
  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
         _isLoading = true;
         _errorMessage = "";
      });
      
      // Check Version
      final prefs = await SharedPreferences.getInstance();
      final bool is2025 = prefs.getBool('is_2025_version') ?? true;
      final String assetPath = is2025 
          ? 'assets/civics_questions_2025.json' 
          : 'assets/civics_questions_2008.json';
          
      // Load full bank
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> data = json.decode(response);
      List<CivicsQuestion> allQuestions = data.map((json) => CivicsQuestion.fromJson(json)).toList();
      
      // Load Seen IDs
      final String seenKey = is2025 ? 'voice_seen_ids' : 'voice_seen_ids_2008';
      List<String> seenIds = prefs.getStringList(seenKey) ?? [];

      // Determine Unseen
      List<CivicsQuestion> unseen = allQuestions.where((q) => !seenIds.contains(q.id)).toList();
      List<CivicsQuestion> selected = [];
      final random = Random();

      // Deck Selection Logic
      if (unseen.length >= 20) {
        unseen.shuffle(random);
        selected = unseen.take(20).toList();
      } else {
        // Take remainders
        selected.addAll(unseen);
        int needed = 20 - unseen.length;
        
        // Reset Logic
        seenIds.clear();
        List<CivicsQuestion> freshDeck = List.from(allQuestions);
        freshDeck.removeWhere((q) => selected.contains(q));
        freshDeck.shuffle(random);
        selected.addAll(freshDeck.take(needed));
      }

      // Update Seen IDs
      Set<String> newSeenSet = seenIds.toSet();
      for (var q in selected) {
        newSeenSet.add(q.id);
      }
      await prefs.setStringList(seenKey, newSeenSet.toList());

      if (mounted) {
        setState(() {
          _questions = selected;
          _isLoading = false;
          _errorMessage = "";
          // Reset session state
          _score = 0;
          _questionIndex = 0;
          _nextQuestion(); 
        });
      }
    } catch (e) {
      print("Error loading civics data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // 3. Pick next question
  void _nextQuestion() {
    if (_questions.isEmpty) return;
    
    // Check if finished (limit 20)
    if (_questionIndex >= _questions.length) {
       _finishSession();
       return;
    }

    setState(() {
      _currentQuestion = _questions[_questionIndex];
      _questionIndex++;
      
      _userSpokenText = "Hold the mic button to speak...";
      _feedbackMessage = "";
      _feedbackColor = Colors.grey;
    });
  }
  
  Future<void> _finishSession() async {
      await StatsService.saveResult(_score, 20); 

      if (!mounted) return;

      bool passed = _score >= 12;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(passed ? "Passed!" : "Keep Practicing"),
          content: Text("You got $_score out of 20 correct.\n${passed ? 'You are ready!' : 'You need 12 to pass.'}"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Close screen
              }, 
              child: const Text("Exit")
            ),
             TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadData(); // Restart
              }, 
              child: const Text("Try Again")
            )
          ],
        ),
      );
  }

  // 4. Start Listening
  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }
    
    setState(() {
      _isListening = true;
      _userSpokenText = "Listening...";
      _feedbackMessage = "";
    });

    await _speech.listen(
      onResult: (val) {
        setState(() {
          _userSpokenText = val.recognizedWords;
        });
      },
      localeId: "en_US",
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  // 5. Stop Listening & Grade
  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    _gradeAnswer();
  }

  // 6. The "Brain": Check if answer is correct
  void _gradeAnswer() {
    if (_currentQuestion == null) return;
    
    bool isCorrect = false;
    final spoken = _userSpokenText.toLowerCase();
    for (var keyword in _currentQuestion!.voiceKeywords) {
      if (spoken.contains(keyword.toLowerCase())) {
        isCorrect = true;
        break;
      }
    }

    setState(() {
      if (isCorrect) {
        _score++; // Increment score only if correct
        _feedbackMessage = "✅ Correct! Great job.";
        _feedbackColor = Colors.green;
        StatsService.removeIncorrect(_currentQuestion!.id);
      } else {
        _feedbackMessage = "❌ Try again. \nHint: ${_currentQuestion!.acceptableAnswers.first}";
        _feedbackColor = Colors.red;
        StatsService.addIncorrect(_currentQuestion!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Oral Quiz")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Read aloud & Answer", style: TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 20),
                    Text(
                      _questions.isEmpty 
                          ? (_isLoading ? "Loading..." : (_errorMessage.isNotEmpty ? "Error: $_errorMessage" : "Error Loading Question"))
                          : (_currentQuestion?.questionText ?? "Error Loading Question"),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    Text(
                      _feedbackMessage,
                      style: TextStyle(fontSize: 18, color: _feedbackColor, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _userSpokenText, 
                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              // Make tap also work for simulators or quick checks if needed, but keeping long press for "Hold to Speak" feel
              child: Container(
                height: 80, width: 80,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : const Color(0xFF112D50),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFF112D50).withOpacity(0.3), blurRadius: 20)]
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none, 
                  color: Colors.white, 
                  size: 40
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Hold to Speak", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            TextButton(
              onPressed: _nextQuestion,
              child: const Text("Next Question ->", style: TextStyle(fontSize: 18)),
            )
          ],
        ),
      ),
    );
  }
}