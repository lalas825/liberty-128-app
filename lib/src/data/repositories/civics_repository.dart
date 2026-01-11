import '../models/civics_question_model.dart';
import '../seeds/questions_2025_seed.dart';

class CivicsRepository {
  /// Simulates fetching questions from a database or API.
  /// [use2025Version] determines whether to return the new 128-question set or the legacy 100-question set.
  Future<List<CivicsQuestion>> getQuestions(bool use2025Version) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    if (use2025Version) {
      return Questions2025Seed.data;
    } else {
      // TODO: Implement legacy 2008 questions seed
      return []; 
    }
  }
}
