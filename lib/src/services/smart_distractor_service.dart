import 'dart:math';
import '../data/models/civics_question_model.dart';

class SmartDistractorService {
  
  /// Generates a randomized list of options (1 Correct + 3 Distractors).
  /// 
  /// [question]: The target question.
  /// [allQuestions]: The full bank of questions to draw distractors from.
  /// 
  /// Returns a List of Maps: {'text': String, 'isCorrect': bool}
  static List<Map<String, dynamic>> generateOptions(
      CivicsQuestion question, List<CivicsQuestion> allQuestions) {
    
    final random = Random();
    
    // 1. Determine Correct Answer
    int requiredAnswers = 1;
    final qText = question.questionText.toLowerCase();
    
    // "Name one" is standard, but "Name two" or "Name three" requires bundling.
    // Note: The prompt specifically asked: "if the question ask for multiple answer, place the answers accordingly"
    if (qText.contains("name two")) requiredAnswers = 2;
    if (qText.contains("name three")) requiredAnswers = 3; 
    // Sometimes it says "What are two..."
    if (qText.contains("what are two")) requiredAnswers = 2;

    List<String> pool = List.from(question.acceptableAnswers);
    pool.shuffle(random);
    
    // Ensure we have enough correct parts (should always be true for valid data)
    List<String> correctParts = pool.take(requiredAnswers).toList();
    if (correctParts.length < requiredAnswers) {
      // Fallback if data is weirdly missing items (unlikely)
      requiredAnswers = correctParts.length; 
    }
    String correctText = correctParts.join(" and ");

    // 2. Generate Smart Distractors
    List<String> distractors = _generateDistractors(question, correctText, requiredAnswers, allQuestions);

    // 3. Shuffle Options
    List<Map<String, dynamic>> options = [
      {'text': correctText, 'isCorrect': true},
      ...distractors.map((d) => {'text': d, 'isCorrect': false}),
    ];
    options.shuffle(random);
    
    return options;
  }

  static List<String> _generateDistractors(
      CivicsQuestion currentQ, String validAnswer, int requiredCount, List<CivicsQuestion> allQuestions) {
    
    final random = Random();
    List<String> distractors = [];
    
    // Helper to check types
    bool isYear(String s) => RegExp(r'^\d{4}$').hasMatch(s);
    bool isNumber(String s) => RegExp(r'^\d+$').hasMatch(s);
    int wordCount(String s) => s.split(' ').length;
    
    bool targetIsYear = isYear(validAnswer);
    bool targetIsNumber = isNumber(validAnswer);
    int targetWordCount = wordCount(validAnswer);
    
    List<CivicsQuestion> candidateQuestions = List.from(allQuestions)..shuffle(random);
    
    for (var q in candidateQuestions) {
       if (q.id == currentQ.id) continue;
       if (distractors.length >= 3) break;
       
       List<String> subPool = List.from(q.acceptableAnswers);
       if (subPool.isEmpty) continue;
       subPool.shuffle(random);
       
       // Try to take enough parts to match the required count (e.g. "Name Two")
       if (subPool.length < requiredCount) continue;
       List<String> parts = subPool.take(requiredCount).toList();
       String candidateText = parts.join(" and ");
       
       // SKIP "Answers will vary" or similar
       if (candidateText.toLowerCase().contains("vary")) continue;
       if (candidateText.toLowerCase().contains("provided")) continue;
       
       // CHECKS
       // 1. Uniqueness
       if (distractors.contains(candidateText)) continue;
       if (candidateText == validAnswer) continue;
       
       // 2. Type/Length Matching
       bool accept = false;
       
       if (targetIsYear) {
         if (isYear(candidateText)) accept = true;
       } else if (targetIsNumber) {
         if (isNumber(candidateText)) accept = true;
       } else {
         // Context Matching
         int wc = wordCount(candidateText);
         // Allow slight variance in word count (Smart Match)
         if ((wc - targetWordCount).abs() <= 2) { 
           accept = true;
         }
         
         // Capitalization heuristic? (Most answers are names/places = capitalized)
         // But "freedom of speech" is not always capped in some datasets? 
         // Let's stick to word count for "structure" matching.
         
         // HARD MODE: If we can't find a perfect word count match after checking chunks options,
         // maybe accept it anyway if it's the best we have? 
         // Implementation Detail: This loop runs through shuffled questions. 
         // If we are too strict, we might get 0 distractors.
       }
       
       if (accept) {
         distractors.add(candidateText);
       }
    }
    
    // Fallback: If we didn't fill 3 slots with strict matching
    if (distractors.length < 3) {
      for (var q in candidateQuestions) {
        if (distractors.length >= 3) break;
        if (q.id == currentQ.id) continue;
        
        List<String> subPool = List.from(q.acceptableAnswers);
        if (subPool.length < requiredCount) continue;
        String t = subPool.take(requiredCount).join(" and ");
        
        if (!t.toLowerCase().contains("vary") && !distractors.contains(t) && t != validAnswer) {
          distractors.add(t);
        }
      }
    }
    
    // Final Fallback (if somehow database is empty or everything matches - highly unlikely)
    while (distractors.length < 3) {
      distractors.add("Option ${distractors.length + 1}");
    }

    return distractors;
  }
}
