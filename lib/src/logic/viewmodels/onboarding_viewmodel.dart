import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liberty_128_app/src/data/models/user_profile_model.dart';

class OnboardingViewModel extends ChangeNotifier {
  DateTime? _selectedDate;
  bool _is2025Version = false;
  bool _isLoading = false;

  // Getters
  DateTime? get selectedDate => _selectedDate;
  bool get is2025Version => _is2025Version;
  bool get isLoading => _isLoading;

  /// Updates the selected date and recalculates the version logic.
  void selectDate(DateTime date) {
    _selectedDate = date;
    
    // Critical Logic: logic from UserProfile model
    _is2025Version = UserProfile.is2025Version(date);
    
    notifyListeners();
  }

  /// Saves the user's filing date and version preference, then navigates home.
  Future<void> saveAndStart(BuildContext context) async {
    if (_selectedDate == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filing_date', _selectedDate!.toIso8601String());
      await prefs.setBool('is_2025_version', _is2025Version);
      await prefs.setBool('has_seen_onboarding', true);

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      // Handle error implicitly or add error state if needed
      debugPrint('Error saving onboarding data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
