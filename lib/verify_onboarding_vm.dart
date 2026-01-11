import 'package:liberty_128_app/src/logic/viewmodels/onboarding_viewmodel.dart';

void main() {
  print('=== Verifying OnboardingViewModel ===\n');

  final viewModel = OnboardingViewModel();

  // Initial State
  print('Initial State:');
  print('Selected Date: ${viewModel.selectedDate}');
  print('Is 2025 Version: ${viewModel.is2025Version}');
  print('Is Loading: ${viewModel.isLoading}');

  // Test 1: Select date BEFORE 2025 cutoff
  final datePrior = DateTime(2025, 1, 1);
  print('\nSelecting date: $datePrior');
  viewModel.selectDate(datePrior);
  print('Is 2025 Version: ${viewModel.is2025Version} (Expected: false)');
  if (!viewModel.is2025Version) print('✅ PASSED'); else print('❌ FAILED');

  // Test 2: Select date AFTER 2025 cutoff
  final dateAfter = DateTime(2025, 11, 1);
  print('\nSelecting date: $dateAfter');
  viewModel.selectDate(dateAfter);
  print('Is 2025 Version: ${viewModel.is2025Version} (Expected: true)');
  if (viewModel.is2025Version) print('✅ PASSED'); else print('❌ FAILED');

  print('\n(Skipping saveAndStart test as it requires Flutter bindings/mocking)');
  
  print('\n=== VERIFICATION COMPLETE ===');
}
