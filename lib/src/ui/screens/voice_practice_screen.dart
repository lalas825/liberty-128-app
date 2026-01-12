import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:confetti/confetti.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/models/civics_question_model.dart';
import '../../data/seeds/questions_2025_seed.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/stats_service.dart';
import '../../services/audio_service.dart';
import '../../logic/providers/user_provider.dart';
import 'package:provider/provider.dart';

class VoicePracticeScreen extends StatefulWidget {
  const VoicePracticeScreen({super.key});

  @override
  State<VoicePracticeScreen> createState() => _VoicePracticeScreenState();
}

class _VoicePracticeScreenState extends State<VoicePracticeScreen> {
  // Tools
  late stt.SpeechToText _speech;
  final SmartAudioService _audio = SmartAudioService();
  late ConfettiController _confettiController;
  
  // Data State
  List<CivicsQuestion> _sessionQuestions = [];
  CivicsQuestion? _currentQuestion;
  bool _isLoading = true;
  String _errorMessage = ""; 
  String _studyVersion = '2025'; 

  // Voice State
  bool _isListening = false;
  bool _speechEnabled = false;
  String _userSpokenText = "Press the mic and speak...";
  String _feedbackMessage = "";
  Color _feedbackColor = Colors.grey;

  // Session State
  int _score = 0;
  int _wrongCount = 0;
  int _questionIndex = 0;
  
  // Logic Constants
  late int _questionsToAsk; 
  late int _scoreToPass;    
  late int _wrongsToFail;   

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initTools();
    _loadInfiniteDeck();
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    _speech.stop();
    _audio.stop();
    super.dispose();
  }
  
  void _initTools() async {
     await _initSpeech();
  }

  Future<void> _initSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      bool available = await _speech.initialize(
        onStatus: (status) => debugPrint('STT Status: $status'),
        onError: (error) => debugPrint('STT Error: $error'),
      );
      if (mounted) setState(() => _speechEnabled = available);
    } else {
      if (mounted) setState(() => _userSpokenText = "Microphone permission denied.");
    }
  }

  // --- 1. INFINITE DECK LOGIC ---
  Future<void> _loadInfiniteDeck() async {
    try {
      if (!mounted) return;
      setState(() { _isLoading = true; _errorMessage = ""; });
      
      final prefs = await SharedPreferences.getInstance();
      final bool is2025 = prefs.getBool('is_2025_version') ?? true;
      _studyVersion = is2025 ? '2025' : '2008';
      
      if (is2025) {
        _questionsToAsk = 20;
        _scoreToPass = 12;
        _wrongsToFail = 9;
      } else {
        _questionsToAsk = 10;
        _scoreToPass = 6;
        _wrongsToFail = 5;
      }

      final String assetPath = is2025 ? 'assets/civics_questions_2025.json' : 'assets/civics_questions_2008.json';
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> data = json.decode(response);
      List<CivicsQuestion> allQuestions = data.map((json) => CivicsQuestion.fromJson(json)).toList();
      
      final String deckKey = is2025 ? 'remaining_ids_2025' : 'remaining_ids_2008';
      List<String> remainingIds = prefs.getStringList(deckKey) ?? [];

      if (remainingIds.isEmpty) {
        remainingIds = allQuestions.map((q) => q.id).toList();
        remainingIds.shuffle(); 
      }

      int countToTake = min(_questionsToAsk, remainingIds.length);
      List<String> sessionIds = remainingIds.take(countToTake).toList();
      
      _sessionQuestions = allQuestions.where((q) => sessionIds.contains(q.id)).toList();
      
      List<String> newRemaining = remainingIds.sublist(countToTake);
      await prefs.setStringList(deckKey, newRemaining);

      if (_sessionQuestions.length < _questionsToAsk) {
         List<String> freshDeck = allQuestions.map((q) => q.id).toList();
         freshDeck.shuffle();
         int needed = _questionsToAsk - _sessionQuestions.length;
         List<String> refillIds = freshDeck.take(needed).toList();
         _sessionQuestions.addAll(allQuestions.where((q) => refillIds.contains(q.id)));
         await prefs.setStringList(deckKey, freshDeck.sublist(needed));
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _score = 0;
          _wrongCount = 0;
          _questionIndex = 0;
          _nextQuestion(); 
        });
      }
    } catch (e) {
      debugPrint("Error loading deck: $e");
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString(); });
    }
  }

  void _nextQuestion() async {
    if (_sessionQuestions.isEmpty) return;
    
    if (_questionIndex >= _sessionQuestions.length) {
       _finishSession(completed: true);
       return;
    }

    setState(() {
      _currentQuestion = _sessionQuestions[_questionIndex];
      _questionIndex++;
      
      _userSpokenText = "Hold mic to speak...";
      _feedbackMessage = "";
      _feedbackColor = Colors.grey;
    });

    await _playCurrentQuestion();
  }

  Future<void> _playCurrentQuestion() async {
    if (_currentQuestion != null) {
      await _audio.playQuestion(_studyVersion, _currentQuestion!.id, _currentQuestion!.questionText);
    }
  }

  // --- 2. GRADING ENGINE ---
  void _gradeAnswer() async {
    if (_currentQuestion == null) return;
    
    bool isCorrect = false;
    final String spoken = _userSpokenText.toLowerCase();
    
    int requiredCount = 1;
    final qText = _currentQuestion!.questionText.toLowerCase();
    if (qText.contains("name two") || qText.contains("state two")) requiredCount = 2;
    if (qText.contains("name three") || qText.contains("state three")) requiredCount = 3;
    
    int matchCount = 0;
    List<String> foundKeywords = [];
    for (var keyword in _currentQuestion!.voiceKeywords) {
       if (spoken.contains(keyword.toLowerCase())) {
         if (!foundKeywords.contains(keyword)) {
            foundKeywords.add(keyword);
            matchCount++;
         }
       }
    }
    
    isCorrect = matchCount >= requiredCount;

    if (isCorrect) {
      setState(() {
        _score++;
        _feedbackMessage = "Correct!";
        _feedbackColor = Colors.green;
      });
      // _playSuccessFeedback(); // Just visual is fine per standard
    } else {
      setState(() {
        _wrongCount++;
        _feedbackMessage = "Incorrect.";
        _feedbackColor = Colors.red;
      });
      
      // Play Intelligent Answer (Uses UserProvider)
      if (mounted) {
         final userProvider = Provider.of<UserProvider>(context, listen: false);
         final answers = _currentQuestion!.acceptableAnswers.take(3).toList();
         final fallbackText = "The answer is ${answers.join(" or ")}";
         
         await _audio.playAnswer(_studyVersion, _currentQuestion!.id, fallbackText, userProvider);
      }
      
      // SAVE ERROR FOR REVIEW
      StatsService.addIncorrect(_currentQuestion!.id);
    }
    
    await Future.delayed(Duration(seconds: isCorrect ? 1 : 4)); 

    if (_checkStopConditions()) return; 
    
    if (mounted) _nextQuestion();
  }

  bool _checkStopConditions() {
    if (_score >= _scoreToPass) {
       _finishSession(passed: true);
       return true;
    }
    
    if (_wrongCount >= _wrongsToFail) {
      _finishSession(passed: false);
      return true;
    }
    
    return false;
  }

  // --- 4. RESULT SCORE CARD (UI) ---
  Future<void> _finishSession({bool? passed, bool completed = false}) async {
      await StatsService.saveResult(_score, _sessionQuestions.length); 
      
      bool finalPass = passed ?? (_score >= _scoreToPass);
      if (finalPass) {
         _confettiController.play();
      }

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Stack(
          alignment: Alignment.center,
          children: [
            // Confetti Overlay
            if (finalPass)
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.orange, Colors.red],
              ),
              
            Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: finalPass ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        finalPass ? Icons.check_circle : Icons.cancel,
                        size: 60,
                        color: finalPass ? Colors.green : Colors.red,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Title
                    Text(
                      finalPass ? "YOU PASSED!" : "STUDY MORE",
                      style: TextStyle(
                         fontSize: 24, 
                         fontWeight: FontWeight.bold,
                         color: finalPass ? Colors.green : Colors.red
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // Score
                    Text(
                      "Score: $_score / ${_sessionQuestions.length}",
                      style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 30),
                    
                    // Buttons
                    // Next Practice
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF112D50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _loadInfiniteDeck(); // Next Batch
                        }, 
                        child: const Text("Next Practice", style: TextStyle(fontSize: 16, color: Colors.white))
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Dashboard
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close screen
                      },
                      child: const Text("Dashboard", style: TextStyle(color: Colors.grey, fontSize: 16))
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }

  // --- VOICE CONTROLS ---
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
      listenFor: const Duration(seconds: 15),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
    _gradeAnswer();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Oral Simulator"),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        titleTextStyle: const TextStyle(color: Color(0xFF112D50), fontWeight: FontWeight.bold, fontSize: 20),
        iconTheme: const IconThemeData(color: Color(0xFF112D50)),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: _questionIndex / _questionsToAsk,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF00C4B4),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Score: $_score", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                Text("Errors: $_wrongCount", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Question Card
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                  ]
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _questionsToAsk == 20 ? "2020 Version" : "2008 Version", 
                      style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 12, letterSpacing: 1.5)
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _currentQuestion?.questionText ?? "...",
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.4, color: Color(0xFF112D50)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    if (_feedbackMessage.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                           color: _feedbackColor.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(12)
                        ),
                        child: Text(
                          _feedbackMessage,
                          style: TextStyle(fontSize: 18, color: _feedbackColor, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Spoken Text Display
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Text(
                _userSpokenText, 
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Mic Button
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 80, width: 80,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.redAccent : const Color(0xFF112D50),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _isListening ? Colors.redAccent.withOpacity(0.4) : const Color(0xFF112D50).withOpacity(0.4), 
                      blurRadius: 15,
                      spreadRadius: _isListening ? 5 : 0
                    )
                  ]
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none, 
                  color: Colors.white, 
                  size: 40
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Hold to Answer", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
