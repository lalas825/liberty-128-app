import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import '../../data/models/civics_question_model.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/smart_distractor_service.dart';

class DailyChallengeModal extends StatefulWidget {
  final List<CivicsQuestion> allQuestions;
  final VoidCallback onChallengeCompleted;

  const DailyChallengeModal({
    super.key,
    required this.allQuestions,
    required this.onChallengeCompleted,
  });

  @override
  State<DailyChallengeModal> createState() => _DailyChallengeModalState();
}

class _DailyChallengeModalState extends State<DailyChallengeModal> {
  final int _totalQuestions = 10;
  List<CivicsQuestion> _quizQuestions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _isLoading = true;
  
  // Current Question State
  List<Map<String, dynamic>> _currentOptions = [];
  bool _answered = false;
  String? _selectedOption;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  void _generateQuiz() {
    final random = Random();
    final List<CivicsQuestion> shuffled = List.from(widget.allQuestions)..shuffle(random);
    
    int count = min(_totalQuestions, shuffled.length);
    _quizQuestions = shuffled.take(count).toList();
    
    _loadQuestion(_currentIndex);
    
    setState(() {
      _isLoading = false;
    });
  }

  void _loadQuestion(int index) {
    if (index >= _quizQuestions.length) return;
    
    final question = _quizQuestions[index];
    
    // Use the Service (Shared Logic)
    final options = SmartDistractorService.generateOptions(question, widget.allQuestions);
    
    setState(() {
      _currentOptions = options;
      _answered = false;
      _selectedOption = null;
    });
  }

  void _handleAnswer(bool isCorrect) {
    if (_answered) return;
    
    setState(() {
      _answered = true;
      if (isCorrect) _score++;
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
       if (_currentIndex < _quizQuestions.length - 1) {
         setState(() {
           _currentIndex++;
           _loadQuestion(_currentIndex);
         });
       } else {
         _finishQuiz();
       }
    });
  }

  void _finishQuiz() {
     bool passed = _score >= 7;
     
     if (passed) {
       DailyChallengeService.completeChallenge();
       widget.onChallengeCompleted(); 
     }
     
     showModalBottomSheet(
       context: context,
       isDismissible: false,
       enableDrag: false,
       builder: (context) => Container(
         padding: const EdgeInsets.all(24),
         height: 300,
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(
               passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
               size: 64,
               color: passed ? const Color(0xFF00C4B4) : Colors.orange,
             ),
             const SizedBox(height: 16),
             Text(
               passed ? "Challenge Completed!" : "Challenge Failed",
               style: GoogleFonts.publicSans(fontSize: 24, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               "You got $_score / $_totalQuestions correct.",
               style: GoogleFonts.publicSans(fontSize: 18),
             ),
             const SizedBox(height: 24),
             if (!passed)
                Text("You need 7/10 to keep your streak.", style: GoogleFonts.publicSans(color: Colors.grey)),
             const SizedBox(height: 24),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF112D50),
                   padding: const EdgeInsets.symmetric(vertical: 16)
                 ),
                 onPressed: () {
                   Navigator.pop(context); // Close Result
                   Navigator.pop(context); // Close Quiz Modal
                 },
                 child: const Text("Close", style: TextStyle(color: Colors.white)),
               ),
             )
           ],
         ),
       )
     );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final question = _quizQuestions[_currentIndex];
    
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.85, 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           Row(
             children: [
               Text("Daily Challenge", style: GoogleFonts.publicSans(color: Colors.grey, fontWeight: FontWeight.bold)),
               const Spacer(),
               Text("${_currentIndex + 1} / $_totalQuestions", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
             ],
           ),
           const SizedBox(height: 4),
           LinearProgressIndicator(
             value: (_currentIndex + 1) / _totalQuestions,
             backgroundColor: Colors.grey.shade200,
             color: const Color(0xFF00C4B4),
           ),
           
           const SizedBox(height: 32),
           
           Text(
             question.questionText, 
             style: GoogleFonts.publicSans(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF112D50))
           ),
           
           const SizedBox(height: 32),
           
           Expanded(
             child: ListView(
               children: _currentOptions.map((opt) {
                 final text = opt['text'] as String;
                 bool isCorrect = opt['isCorrect'] as bool;
                 
                 Color bgColor = Colors.white;
                 Color textColor = const Color(0xFF112D50);
                 Color borderColor = Colors.grey.shade300;
                 
                 if (_answered) {
                   if (isCorrect) {
                     bgColor = const Color(0xFFE0F2F1); 
                     borderColor = const Color(0xFF00C4B4);
                     textColor = const Color(0xFF004D40);
                   } else if (_selectedOption == text && !isCorrect) {
                      bgColor = const Color(0xFFFFEBEE); 
                      borderColor = Colors.redAccent;
                      textColor = Colors.red.shade900;
                   }
                 }
                 
                 return Padding(
                   padding: const EdgeInsets.only(bottom: 12),
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: bgColor,
                       foregroundColor: textColor,
                       elevation: 0,
                       side: BorderSide(color: borderColor, width: 1.5),
                       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                     ),
                     onPressed: _answered ? null : () {
                       setState(() {
                         _selectedOption = text;
                       });
                       _handleAnswer(isCorrect);
                     },
                     child: Text(
                       text, 
                       textAlign: TextAlign.center,
                       style: GoogleFonts.publicSans(
                         fontSize: 16, 
                         fontWeight: FontWeight.w500 
                       )
                     ),
                   ),
                 );
               }).toList(),
             ),
           ),
        ],
      ),
    );
  }
}
