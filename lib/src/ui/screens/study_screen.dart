import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/civics_question_model.dart';
import 'dart:math' as math; // For simple card flip animation if needed

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<CivicsQuestion> _questions = [];
  List<CivicsQuestion> _originalQuestions = []; // For standard order
  bool _isLoading = true;
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isShuffled = false;
  
  // Persistence Keys
  static const String KEY_PROGRESS_2008 = 'study_progress_2008';
  static const String KEY_PROGRESS_2025 = 'study_progress_2025';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool is2025 = prefs.getBool('is_2025_version') ?? true;
      final String assetPath = is2025 
          ? 'assets/civics_questions_2025.json' 
          : 'assets/civics_questions_2008.json';

      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> data = json.decode(response);
      
      final loadedQuestions = data.map((json) => CivicsQuestion.fromJson(json)).toList();
      
      setState(() {
        _questions = List.from(loadedQuestions);
        _originalQuestions = List.from(loadedQuestions);
        _isLoading = false;
      });
      
      await _loadProgress(is2025);
      
    } catch (e) {
      debugPrint("Error loading study questions: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProgress(bool is2025) async {
     final prefs = await SharedPreferences.getInstance();
     final key = is2025 ? KEY_PROGRESS_2025 : KEY_PROGRESS_2008;
     final savedIndex = prefs.getInt(key) ?? 0;
     
     if (savedIndex < _questions.length && savedIndex >= 0) {
        setState(() => _currentIndex = savedIndex);
     }
  }

  Future<void> _saveProgress() async {
    if (_isShuffled) return; // Don't save progress in shuffle mode (optional choice, but standard)
    
    final prefs = await SharedPreferences.getInstance();
    final bool is2025 = prefs.getBool('is_2025_version') ?? true;
    final key = is2025 ? KEY_PROGRESS_2025 : KEY_PROGRESS_2008;
    
    await prefs.setInt(key, _currentIndex);
  }
  
  void _resetProgress() async {
    setState(() {
      _currentIndex = 0;
      _isFlipped = false;
    });
    if (!_isShuffled) await _saveProgress();
    
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text("Progress Reset to Start"), duration: Duration(seconds: 1))
    );
  }

  void _toggleShuffle() {
     setState(() {
        _isShuffled = !_isShuffled;
        _isFlipped = false;
        _currentIndex = 0; // Always start fresh on mode switch for clarity
        
        if (_isShuffled) {
           _questions.shuffle();
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Shuffle Mode: ON (Random Order)"), duration: Duration(seconds: 1))
           );
        } else {
           _questions = List.from(_originalQuestions); // Restore order
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Standard Order Restored"), duration: Duration(seconds: 1))
           );
           // Ideally restore persistence here? 
           // For now, reset to 0 is safer/simpler ui flow, or re-load persistence.
           // Let's re-load persistence to be "Smart".
           _reloadPersistence();
        }
     });
  }
  
  void _reloadPersistence() async {
      final prefs = await SharedPreferences.getInstance();
      final bool is2025 = prefs.getBool('is_2025_version') ?? true;
      _loadProgress(is2025);
  }

  void _nextCard() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
      _saveProgress();
    }
  }

  void _prevCard() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
      _saveProgress();
    }
  }

  void _flipCard() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No questions found.")),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Flashcards", style: GoogleFonts.publicSans(color: const Color(0xFF112D50), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Managed by main nav
        actions: [
          IconButton(
            icon: Icon(Icons.shuffle, color: _isShuffled ? const Color(0xFF112D50) : Colors.grey),
            onPressed: _toggleShuffle,
            tooltip: "Toggle Shuffle",
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF112D50)),
            onPressed: _resetProgress,
            tooltip: "Reset Progress",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C4B4)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Question ${_currentIndex + 1} of ${_questions.length}",
              style: GoogleFonts.publicSans(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
            ),
          ),
          
          // Flashcard Area
          Expanded(
            child: GestureDetector(
              onTap: _flipCard,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final rotateAnim = Tween(begin: math.pi, end: 0.0).animate(animation);
                  return AnimatedBuilder(
                    animation: rotateAnim,
                    child: child,
                    builder: (context, child) {
                      final isUnder = (ValueKey(_isFlipped) != child!.key);
                      var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder ? math.min(rotateAnim.value, math.pi / 2) : rotateAnim.value;
                      // Simple fade scale transition is often safer/easier without 3D math package
                      // But let's stick to a simple switcher fade/scale for robustness
                      return FadeTransition(opacity: animation, child: child);
                    },
                  );
                },
                child: _isFlipped 
                    ? _buildBack(question) 
                    : _buildFront(question),
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _currentIndex > 0 ? _prevCard : null,
                  icon: const Icon(Icons.arrow_back_ios),
                  color: const Color(0xFF112D50),
                  iconSize: 32,
                ),
                ElevatedButton(
                  onPressed: _flipCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF112D50),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 4,
                  ),
                  child: Text(
                    _isFlipped ? "Show Question" : "Show Answer",
                    style: GoogleFonts.publicSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: _currentIndex < _questions.length - 1 ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward_ios),
                  color: const Color(0xFF112D50),
                  iconSize: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront(CivicsQuestion q) {
    return Container(
      key: const ValueKey(false),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF112D50).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(color: Colors.grey.shade100, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "QUESTION",
            style: GoogleFonts.publicSans(
              color: const Color(0xFF00C4B4),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            q.questionText,
            style: GoogleFonts.publicSans(
              color: const Color(0xFF112D50),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBack(CivicsQuestion q) {
    return Container(
      key: const ValueKey(true),
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF112D50),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF112D50).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "ANSWER",
            style: GoogleFonts.publicSans(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Show ALL acceptable answers
          ...q.acceptableAnswers.map((ans) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "• $ans",
              style: GoogleFonts.publicSans(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          )).toList(),
        ],
      ),
    );
  }
}
