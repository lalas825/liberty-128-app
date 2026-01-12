import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../logic/providers/user_provider.dart';
import '../../services/stats_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../data/models/civics_question_model.dart';
import 'review_errors_screen.dart';
import 'study_screen.dart';
import 'podcast_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart'; // Added
import 'n400_vocab_screen.dart';
import '../widgets/daily_challenge_modal.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 1; // Default to Home (Center)
  
  // Dashboard State
  double _passProbability = 0.0;
  String _statusLabel = "Start Practicing";
  bool _isPassed = false;
  Color _statusColor = Colors.grey;
  
  // Daily Challenge State
  bool _isChallengeCompleted = false;
  int _challengeStreak = 0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _loadStats();
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

  Future<void> _loadStats() async {
    final stats = await StatsService.getStats();
    if (!mounted) return;
    setState(() {
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
  
  Future<void> _startDailyChallenge() async {
    if (_isChallengeCompleted) return;
    
    try {
        final String jsonString = await DefaultAssetBundle.of(context).loadString('assets/civics_questions_2025.json');
        final List<dynamic> jsonList = jsonDecode(jsonString);
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
                 _loadChallengeState();
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

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Reload stats when switching back to home
    if (index == 1) { // Home index is now 1
      _loadStats();
      _loadChallengeState();
      if (mounted) {
        Provider.of<UserProvider>(context, listen: false).refresh();
      }
    }
  }

  // Logic: Calculate Days Until Exam
  String _getDaysUntilExam(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exam = DateTime(date.year, date.month, date.day);
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
          const SettingsScreen(), // Index 0
          _buildDashboard(),      // Index 1 (Home)
          const ProfileScreen(),  // Index 2
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: federalBlue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    final Color federalBlue = const Color(0xFF112D50);
    final Color bgLight = const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        title: Text("Dashboard",
            style: GoogleFonts.publicSans(
                color: federalBlue, fontWeight: FontWeight.bold)),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          // 1. HEADER (Profile & Countdown)
          _buildHeaderSection(federalBlue),
          
          const SizedBox(height: 24),
          
          // 2. ACTION CARDS LIST
          
          // Oral Simulator
          GestureDetector(
             onTap: () {
                Navigator.pushNamed(context, '/voice').then((_) => _loadStats());
             },
             child: _buildLargeActionCard(
               icon: Icons.mic,
               color: Colors.blue,
               title: "Oral Simulator",
               subtitle: "Practice Speaking"
             ),
          ),
          
          const SizedBox(height: 16),
          
          // Podcast Mode
          GestureDetector(
             onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const PodcastScreen()));
             },
             child: _buildLargeActionCard(
               icon: Icons.headphones,
               color: Colors.purple, // Distinct color
               title: "Podcast Mode",
               subtitle: "Hands-free Audio Study"
             ),
          ),
          
          const SizedBox(height: 16),
          
          // Study Mode
          GestureDetector(
             onTap: () {
                // Navigate to Study Screen logic (or create a dedicated study route if needed, 
                // currently StudyScreen is a tab, but we can push it or just switch tabs?)
                // The requirements say "Study Mode". For now I'll create a push to StudyScreen 
                // or I can repurpose/reuse. Since StudyScreen is complex, let's push it.
                Navigator.push(context, MaterialPageRoute(builder: (c) => const StudyScreen()));
             },
             child: _buildLargeActionCard(
               icon: Icons.school,
               color: Colors.indigo,
               title: "Study Mode",
               subtitle: "Flashcards & Memorization"
             ),
          ),
          
          const SizedBox(height: 16),
          
          // Review Errors
          GestureDetector(
             onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const ReviewErrorsScreen())).then((_) => _loadStats());
             },
             child: _buildLargeActionCard(
               icon: Icons.warning_amber_rounded,
               color: Colors.orange,
               title: "Review Errors",
               subtitle: "Fix Your Mistakes"
             ),
          ),
          
          const SizedBox(height: 16),

          // N-400 Vocab
          GestureDetector(
             onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const N400VocabScreen()));
             },
             child: _buildLargeActionCard(
               icon: Icons.menu_book,
               color: Colors.deepPurple,
               title: "N-400 Vocab",
               subtitle: "Reading & Writing"
             ),
          ),
          
          const SizedBox(height: 16),

          // Daily Challenge
          GestureDetector(
             onTap: _startDailyChallenge,
             child: _buildLargeActionCard(
               icon: Icons.local_fire_department,
               color: Colors.redAccent,
               title: "Daily Challenge",
               subtitle: _isChallengeCompleted ? "Streak: $_challengeStreak Days" : "Keep your streak",
               isCompleted: _isChallengeCompleted,
             ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  
  // Helper for Header (Profile + Countdown)
  Widget _buildHeaderSection(Color federalBlue) {
    return Consumer<UserProvider>(
       builder: (context, userProvider, _) {
          final name = userProvider.userName ?? "";
          final photo = userProvider.photoUrl;
          final examDate = userProvider.examDate;
          
          return Column(
            children: [
               // Profile Row
               Row(
                  children: [
                    Container(
                      width: 48, 
                      height: 48,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade300),
                      child: ClipOval(
                        child: photo != null
                            ? Image.network(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : "U",
                                      style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: federalBlue),
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                   if (loadingProgress == null) return child;
                                   return const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
                                },
                              )
                            : Center(
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : "U",
                                  style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: federalBlue),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hi, ${name.isNotEmpty ? name : 'Friend'}", 
                           style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.bold, color: federalBlue)),
                        Text("${userProvider.studyVersion} Version", 
                           style: GoogleFonts.publicSans(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
               ),
               
               if (examDate != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [federalBlue, federalBlue.withOpacity(0.9)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: federalBlue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        ]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(_getDaysUntilExam(examDate),
                            style: GoogleFonts.publicSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
               ]
            ],
          );
       }
    );
  }

  // New Large Action Card
  Widget _buildLargeActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool isCompleted = false,
  }) {
    // Style similar to the Daily Challenge card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: isCompleted ? const Color(0xFFE0F2F1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCompleted 
             ? Border.all(color: const Color(0xFF00C4B4), width: 1.5)
             : null,
          boxShadow: const [
             BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))
          ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCompleted ? const Color(0xFF00C4B4).withOpacity(0.2) : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : icon,
              color: isCompleted ? const Color(0xFF00C4B4) : color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.publicSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF112D50)),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.publicSans(
                    color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          if (!isCompleted)
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey)
        ],
      ),
    );
  }
}
