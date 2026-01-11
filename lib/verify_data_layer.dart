import 'package:liberty_128_app/src/data/models/civics_question_model.dart';
import 'package:liberty_128_app/src/data/repositories/civics_repository.dart';

void main() async {
  print('--- Verifying Data Layer ---');

  // Test Repository
  final repo = CivicsRepository();
  print('Fetching 2025 questions...');
  final questions = await repo.getQuestions(true);
  
  print('Fetched ${questions.length} questions.');

  if (questions.isEmpty) {
    print('ERROR: No questions returned.');
    return;
  }

  // Test Model & Fuzzy Logic
  final q1 = questions.first;
  print('\nTesting Question: ${q1.questionText}');
  print('Keywords: ${q1.voiceKeywords}');

  void checkAnswer(String input) {
    final result = q1.isCorrect(input);
    print('Input: "$input" -> Correct? $result');
  }

  checkAnswer('The Constitution'); // Exact match
  checkAnswer('I think it is the constitution'); // Contains keyword
  checkAnswer('The Declaration of Independence'); // Wrong

  print('\n--- Verification Complete ---');
}
