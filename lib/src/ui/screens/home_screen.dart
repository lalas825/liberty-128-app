import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/stats_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../data/models/civics_question_model.dart';
import 'quiz_screen.dart';
import 'review_errors_screen.dart';
import 'study_screen.dart';
import 'profile_screen.dart';
import 'n400_vocab_screen.dart';
import '../widgets/daily_challenge_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // Dashboard State
  double _passProbability = 0.0;
  String _statusLabel = "Start Practicing";
  bool _isPassed = false;
  Color _statusColor = Colors.grey;
  
  // Profile Data for Dashboard
  String _userName = "";
  DateTime? _examDate;
  
  // Daily Challenge State
  bool _isChallengeCompleted = false;
  int _challengeStreak = 0;

  final List<Widget> _screens = [
     Container(), // Placeholder for Dashboard (index 0)
     const StudyScreen(),
     const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadStats();
    await _loadProfile();
    await _loadChallengeState();
  }
  
  Future<void> _loadChallengeState() async {
    await DailyChallengeService.checkStreak();
    final state = await DailyChallengeService.getChallengeState();
    if (mounted) {
      setState(() {
        _challengeStreak = state['streak'];
        _isChallengeCompleted = state['isCompleted'];
      });
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "";
      final dateStr = prefs.getString('exam_date');
      if (dateStr != null) {
        _examDate = DateTime.tryParse(dateStr);
      }
    });
  }

  Future<void> _loadStats() async {
    final stats = await StatsService.getStats();
    // Also reload name in case it changed in Profile tab
    final prefs = await SharedPreferences.getInstance(); 
    
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? "";
      final dateStr = prefs.getString('exam_date');
      if (dateStr != null) {
        _examDate = DateTime.tryParse(dateStr);
      } else {
        _examDate = null;
      }

      _passProbability = stats['average_score'];
      _isPassed = stats['passed'];
      
      if (stats['total_attempts'] == 0) {
        _statusLabel = "Start Practicing";
        _statusColor = Colors.grey;
      } else {
        _statusLabel = _isPassed ? "Passed" : "Failed";
        _statusColor = _isPassed ? const Color(0xFF00C4B4) : Colors.redAccent;
      }
    });
  }

  // --- DAILY CHALLENGE LOGIC ---
  
  // --- DAILY CHALLENGE LOGIC ---
  
  Future<void> _startDailyChallenge() async {
    if (_isChallengeCompleted) return;
    
    try {
        final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/civics_questions_2025.json');
        final List<dynamic> jsonList = jsonDecode(jsonString); // Requires dart:convert
        final List<CivicsQuestion> allQuestions = jsonList.map((json) => CivicsQuestion.fromJson(json)).toList();
        
        if (!mounted) return;
        
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (context) {
            return DailyChallengeModal(
              allQuestions: allQuestions,
              onChallengeCompleted: () {
                 _loadChallengeState(); // Refresh UI on completion
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Challenge Completed! Streak Updated.", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFF00C4B4),
                    )
                 );
              },
            );
          }
        );

    } catch (e) {
      debugPrint("Error loading challenge: $e");
    }
  }
  
  // _handleChallengeResult is no longer needed in HomeScreen as logic is in Modal
  // But removing it would break the file if I replaced _startDailyChallenge only partially.
  // The ReplacementContent above replaces the entire block UP TO _onTabTapped potentially?
  // I need to be careful with the range.
  
  // The tool instructions say: "StartLine to EndLine".
  // I will target the logic block specifically.


  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Reload stats/name when switching back to home
    if (index == 0) {
      _loadStats();
      _loadProfile();
      _loadChallengeState();
    }
  }

  // Logic: Calculate Days Until Exam
  String _getDaysUntilExam() {
    if (_examDate == null) return "Set Exam Date";
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(_examDate!.year, _examDate!.month, _examDate!.day);
    final difference = exam.difference(today).inDays;

    if (difference < 0) return "Interview Passed!";
    if (difference == 0) return "Interview Today!";
    return "$difference Days Until Interview";
  }

  @override
  Widget build(BuildContext context) {
    final Color federalBlue = const Color(0xFF112D50);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboard(), // Index 0
          const StudyScreen(), // Index 1
          const ProfileScreen(), // Index 2
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: federalBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Study"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final Color federalBlue = const Color(0xFF112D50);
    final Color citizenGreen = const Color(0xFF00C4B4);
    final Color bgLight = const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        title: Text("Dashboard",
            style: GoogleFonts.publicSans(
                color: federalBlue, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.blueGrey),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
          ),
          IconButton(
              icon: Icon(Icons.refresh, color: federalBlue), 
              onPressed: _loadStats)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // PROFILE HEADER
            Row(
              children: [
                CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey.shade300,
                    child: Text(
                       _userName.isNotEmpty ? _userName[0].toUpperCase() : "U",
                       style: GoogleFonts.publicSans(fontSize: 24, fontWeight: FontWeight.bold, color: federalBlue),
                    )),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_userName.isNotEmpty ? "Hi, $_userName" : "Welcome back,",
                        style: GoogleFonts.publicSans(
                            color: federalBlue,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Text("Preparing for 2025 Version",
                        style: GoogleFonts.publicSans(
                            color: Colors.grey, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // COUNTDOWN TIMER CARD
            if (_examDate != null)
              GestureDetector(
                onTap: () {
                   // Navigate to Profile Tab (Index 2)
                   _onTabTapped(2);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [federalBlue, federalBlue.withOpacity(0.85)]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: federalBlue.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ]),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(width: 10),
                          Text(_getDaysUntilExam(),
                              style: GoogleFonts.publicSans(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("Tap to edit date", 
                         style: GoogleFonts.publicSans(color: Colors.white70, fontSize: 12))
                    ],
                  ),
                ),
              ),



            // PASS PROBABILITY (Dynamic)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10)
                  ]),
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    width: 150,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                            value: _passProbability,
                            strokeWidth: 12,
                            backgroundColor: Colors.grey.shade200,
                            color: _isPassed ? citizenGreen : (_passProbability > 0 ? Colors.redAccent : Colors.grey)),
                        Center(
                            child: Text("${(_passProbability * 100).toInt()}%",
                                style: GoogleFonts.publicSans(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: federalBlue))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_statusLabel,
                      style: GoogleFonts.publicSans(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _statusColor)),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ACTION CARDS (GRID LAYOUT)
            Column(
              children: [
                // ROW 1: The Main Tests
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const QuizScreen()),
                          ).then((_) => _loadStats());
                        },
                        child: _buildActionCard(
                          icon: Icons.assignment,
                          color: Colors.green,
                          title: "Civics Quiz",
                          subtitle: "Practice Mode",
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/voice')
                              .then((_) => _loadStats());
                        },
                        child: _buildActionCard(
                          icon: Icons.mic,
                          color: Colors.blue,
                          title: "Oral Quiz",
                          subtitle: "Exam",
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ROW 2: Study Tools
                Row(
                  children: [
                    // 1. Review Errors
                    Expanded(
                      child: GestureDetector(
                         onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ReviewErrorsScreen()),
                          ).then((_) => _loadStats());
                        },
                        child: _buildActionCard(
                          icon: Icons.warning_amber_rounded,
                          color: Colors.orange,
                          title: "Review Errors",
                          subtitle: "Fix Mistakes",
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 2. N-400 Vocabulary
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                           Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const N400VocabScreen()),
                          );
                        },
                        child: _buildActionCard(
                          icon: Icons.menu_book,
                          color: Colors.deepOrangeAccent,
                          title: "N-400 Vocab",
                          subtitle: "Definitions",
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // DAILY CHALLENGE CARD
            GestureDetector(
              onTap: _startDailyChallenge,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 30),
                decoration: BoxDecoration(
                    color: _isChallengeCompleted ? const Color(0xFFE0F2F1) : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isChallengeCompleted ? citizenGreen : Colors.orangeAccent,
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isChallengeCompleted ? citizenGreen.withOpacity(0.2) : Colors.orangeAccent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isChallengeCompleted ? Icons.check_circle : Icons.local_fire_department,
                        color: _isChallengeCompleted ? citizenGreen : Colors.deepOrange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isChallengeCompleted ? "Great Job!" : "Daily Challenge",
                          style: GoogleFonts.publicSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: federalBlue),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isChallengeCompleted 
                             ? "Streak: $_challengeStreak Days" 
                             : "Keep your streak alive!",
                          style: GoogleFonts.publicSans(
                              color: Colors.grey.shade700, fontSize: 14),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!_isChallengeCompleted)
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for the Cards
  Widget _buildActionCard(
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(title,
              style: GoogleFonts.publicSans(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          Text(subtitle,
              style: GoogleFonts.publicSans(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
