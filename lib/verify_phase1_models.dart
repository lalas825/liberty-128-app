import 'package:liberty_128_app/src/data/models/user_profile_model.dart';
import 'package:liberty_128_app/src/data/seeds/questions_2025_seed.dart';

void main() {
  print('=== verifying PHASE 1 LOGIC ===\n');

  // TEST 1: UserProfile Version Logic
  print('--- Testing Version Control Logic ---');
  final datePrior = DateTime(2025, 10, 19);
  final dateOn = DateTime(2025, 10, 20);
  final dateAfter = DateTime(2025, 10, 21);

  print('Filing Date $datePrior: is2025? ${UserProfile.is2025Version(datePrior)} (Expected: false)');
  print('Filing Date $dateOn: is2025? ${UserProfile.is2025Version(dateOn)} (Expected: true)');
  print('Filing Date $dateAfter: is2025? ${UserProfile.is2025Version(dateAfter)} (Expected: true)');

  if (UserProfile.is2025Version(dateOn) == true && UserProfile.is2025Version(datePrior) == false) {
    print('✅ Version Control Logic PASSED');
  } else {
    print('❌ Version Control Logic FAILED');
  }

  // TEST 2: Voice Validation Logic
  print('\n--- Testing Voice Validation (Fuzzy Matching) ---');
  final q1 = Questions2025Seed.data.first; // "What is the supreme law of the land?" Keywords: ['Constitution']
  
  print('Question: ${q1.questionText}');
  print('Keywords: ${q1.voiceKeywords}');

  _testVoice(q1, 'The Constitution', true);
  _testVoice(q1, 'I think it is the CONSTITUTION', true); // Case insensitive check
  _testVoice(q1, 'Freedom of Speech', false);
  
  print('\n=== VERIFICATION COMPLETE ===');
}

void _testVoice(question, String input, bool expected) {
  final result = question.isSpokenMatch(input);
  final matchIcon = result == expected ? '✅' : '❌';
  print('$matchIcon Input: "$input" -> Result: $result (Expected: $expected)');
}
