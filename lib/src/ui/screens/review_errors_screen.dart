import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/civics_question_model.dart';
import '../../services/stats_service.dart';

class ReviewErrorsScreen extends StatefulWidget {
  const ReviewErrorsScreen({super.key});

  @override
  State<ReviewErrorsScreen> createState() => _ReviewErrorsScreenState();
}

class _ReviewErrorsScreenState extends State<ReviewErrorsScreen> {
  List<CivicsQuestion> _errorQuestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadErrors();
  }

  Future<void> _loadErrors() async {
    setState(() => _isLoading = true);

    try {
      // 1. Get IDs
      final List<String> errorIds = await StatsService.getIncorrectIds();

      if (errorIds.isEmpty) {
        setState(() {
          _errorQuestions = [];
          _isLoading = false;
        });
        return;
      }

      // 2. Load ALL Data (Both Versions to be safe)
      // This is efficient enough for ~200 items in JSON
      final String json2025 = await rootBundle.loadString('assets/civics_questions_2025.json');
      final String json2008 = await rootBundle.loadString('assets/civics_questions_2008.json');

      final List<dynamic> data2025 = json.decode(json2025);
      final List<dynamic> data2008 = json.decode(json2008);

      final Map<String, CivicsQuestion> lookup = {};

      for (var item in data2025) {
        final q = CivicsQuestion.fromJson(item);
        lookup[q.id] = q;
      }
      for (var item in data2008) {
        final q = CivicsQuestion.fromJson(item);
        lookup[q.id] = q;
      }

      // 3. Map IDs to Questions
      final List<CivicsQuestion> found = [];
      for (String id in errorIds) {
        if (lookup.containsKey(id)) {
          found.add(lookup[id]!);
        }
      }

      setState(() {
        _errorQuestions = found;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading review data: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsLearned(String id) async {
    await StatsService.removeIncorrect(id);
    _loadErrors(); // Reload list
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marked as learned!"), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Review Errors", style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: const Color(0xFF112D50))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF112D50)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorQuestions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                      const SizedBox(height: 16),
                      Text("No errors found!", style: GoogleFonts.publicSans(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text("Great job! Go practice more.", style: GoogleFonts.publicSans(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _errorQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _errorQuestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: const Icon(Icons.warning, color: Colors.orange),
                        title: Text(
                          q.questionText,
                          style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          "Tap to see correct answer",
                          style: GoogleFonts.publicSans(fontSize: 12, color: Colors.grey),
                        ),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: Colors.grey.shade50,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CORRECT ANSWER:",
                                  style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  q.acceptableAnswers.join('\nOR '),
                                  style: GoogleFonts.publicSans(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF112D50)),
                                ),
                                if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    "EXPLANATION:",
                                    style: GoogleFonts.publicSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.explanation!,
                                    style: GoogleFonts.publicSans(fontSize: 14, color: Colors.black87),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _markAsLearned(q.id),
                                    icon: const Icon(Icons.check),
                                    label: const Text("I Learned This"),
                                  ),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
