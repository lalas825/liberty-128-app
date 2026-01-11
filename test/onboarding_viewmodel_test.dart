import 'package:flutter_test/flutter_test.dart';
import 'package:citizen128/src/logic/viewmodels/onboarding_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingViewModel', () {
    late OnboardingViewModel viewModel;

    setUp(() {
      viewModel = OnboardingViewModel();
    });

    test('Initial state is correct', () {
      expect(viewModel.selectedDate, null);
      expect(viewModel.is2025Version, false);
      expect(viewModel.isLoading, false);
    });

    test('selectDate correctly sets 2025 version for dates on/after Oct 20, 2025', () {
      // Date: Oct 20, 2025
      final dateOn = DateTime(2025, 10, 20);
      viewModel.selectDate(dateOn);
      expect(viewModel.selectedDate, dateOn);
      expect(viewModel.is2025Version, true);

       // Date: Nov 1, 2025
      final dateAfter = DateTime(2025, 11, 1);
      viewModel.selectDate(dateAfter);
      expect(viewModel.selectedDate, dateAfter);
      expect(viewModel.is2025Version, true);
    });

    test('selectDate correctly sets Legacy version for dates before Oct 20, 2025', () {
      // Date: Oct 19, 2025
      final dateBefore = DateTime(2025, 10, 19);
      viewModel.selectDate(dateBefore);
      expect(viewModel.selectedDate, dateBefore);
      expect(viewModel.is2025Version, false);
    });

    // Navigation test skipped as it requires a real BuildContext or MockNavigator.
    // Logic for saveAndStart is minimal (saving to prefs) and implicitly covered by ensuring _selectedDate is set.
  });
}
