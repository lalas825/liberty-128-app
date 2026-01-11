import 'package:shared_preferences/shared_preferences.dart';

class StatsService {
  static const String _statsKey = 'quiz_stats_history';

  static const String _incorrectKey = 'quiz_incorrect_ids';

  // Save a result (score and total questions)
  static Future<void> saveResult(int score, int total) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_statsKey) ?? [];
    
    // Format: "score/total|timestamp"
    String entry = "$score/$total|${DateTime.now().millisecondsSinceEpoch}";
    history.add(entry);
    
    await prefs.setStringList(_statsKey, history);
  }

  // --- INCORRECT ANSWER TRACKING ---
  
  static Future<void> addIncorrect(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> incorrectIds = prefs.getStringList(_incorrectKey) ?? [];
    if (!incorrectIds.contains(questionId)) {
      incorrectIds.add(questionId);
      await prefs.setStringList(_incorrectKey, incorrectIds);
    }
  }

  static Future<void> removeIncorrect(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> incorrectIds = prefs.getStringList(_incorrectKey) ?? [];
    if (incorrectIds.contains(questionId)) {
      incorrectIds.remove(questionId);
      await prefs.setStringList(_incorrectKey, incorrectIds);
    }
  }

  static Future<List<String>> getIncorrectIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_incorrectKey) ?? [];
  }
  
  // ---------------------------------

  // Get aggregated stats
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_statsKey) ?? [];

    if (history.isEmpty) {
      return {
        'average_score': 0.0,
        'total_attempts': 0,
        'passed': false,
        'label': 'Start Practicing'
      };
    }

    double totalPercentage = 0;
    int acceptedAttempts = 0;
    // Calculation: Average of Percentages = (Sum of (Score/Total)) / Count
    // Alternatively: (Sum of All Scores) / (Sum of All Totals) - simpler but might skew if test lengths vary wildly.
    // Given the user wants "Pass Probability", average of percentages is usually safer if test sizes differ, 
    // but here tests are fixed at 20. So (TotalCorrect / TotalAsked) is accurate.
    
    int totalCorrect = 0;
    int totalQuestions = 0;

    for (String entry in history) {
      try {
        // Parse "score/total|timestamp"
        var parts = entry.split('|')[0].split('/');
        int s = int.parse(parts[0]);
        int t = int.parse(parts[1]);
        
        if (t > 0) {
           totalCorrect += s;
           totalQuestions += t;
           acceptedAttempts++;
        }
      } catch (e) {
        // skip malformed
      }
    }

    if (totalQuestions == 0) return {'average_score': 0.0, 'passed': false, 'label': 'No Data'};

    double average = totalCorrect / totalQuestions;
    bool passed = average >= 0.60; // 12/20 is 60%

    return {
      'average_score': average,
      'total_attempts': acceptedAttempts,
      'passed': passed,
      'label': passed ? 'Passed' : 'Failed'
    };
  }
  
  static Future<void> clearStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
  }
}
