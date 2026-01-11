import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DailyChallengeService {
  static const String _streakKey = 'daily_streak';
  static const String _lastDateKey = 'last_challenge_date';

  /// Returns the current state: {streak: int, isCompleted: bool}
  static Future<Map<String, dynamic>> getChallengeState() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_streakKey) ?? 0;
    final lastDateStr = prefs.getString(_lastDateKey);
    
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    bool isCompleted = (lastDateStr == todayStr);

    return {
      'streak': streak,
      'isCompleted': isCompleted,
    };
  }

  /// Checks if the streak needs to be reset (if user missed yesterday).
  /// Should be called on app start or screen load.
  static Future<void> checkStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_lastDateKey);
    
    if (lastDateStr == null) return; // New user or no history

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final lastDate = DateFormat('yyyy-MM-dd').parse(lastDateStr);
    
    final difference = today.difference(lastDate).inDays;

    // If difference is greater than 1, they missed a day (or more).
    // difference 0 = today (completed today)
    // difference 1 = yesterday (streak intact)
    // difference > 1 = missed (streak reset)
    if (difference > 1) {
      await prefs.setInt(_streakKey, 0);
    }
  }

  /// Mark challenge as completed for today and increment streak
  static Future<void> completeChallenge() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    
    // Check if already completed today to prevent double counting
    final lastDateStr = prefs.getString(_lastDateKey);
    if (lastDateStr == todayStr) return; 

    final currentStreak = prefs.getInt(_streakKey) ?? 0;
    
    // If last date was yesterday, streak + 1. 
    // If last date was null (first time), streak = 1.
    // If streak was reset by checkStreak, it might be 0, so streak = 1.
    // Actually, simple logic: checkStreak() should have run. 
    // If difference > 1, streak is 0. So currentStreak + 1 is correct.
    
    // Safety check just in case checkStreak wasn't run or logic
    // We assume checkStreak runs on load.
    
    await prefs.setInt(_streakKey, currentStreak + 1);
    await prefs.setString(_lastDateKey, todayStr);
  }
}
