class CivicsQuestion {
  final String id;
  final String questionText;
  final List<String> acceptableAnswers;
  final List<String> voiceKeywords;
  final String explanation;
  final String section;
  final bool is2025Only;

  const CivicsQuestion({
    required this.id,
    required this.questionText,
    required this.acceptableAnswers,
    required this.voiceKeywords,
    required this.explanation,
    required this.section,
    required this.is2025Only,
  });

  factory CivicsQuestion.fromJson(Map<String, dynamic> json) {
    return CivicsQuestion(
      id: json['id'] as String? ?? '',
      questionText: (json['question_text'] ?? json['questionText']) as String,
      acceptableAnswers: List<String>.from((json['acceptable_answers'] ?? json['acceptableAnswers'] ?? []) as List),
      voiceKeywords: List<String>.from((json['voice_keywords'] ?? json['voiceKeywords'] ?? []) as List),
      explanation: (json['explanation_why'] ?? json['explanation']) as String? ?? '',
      section: (json['section'] ?? '') as String,
      is2025Only: (json['is_premium_content'] ?? json['is2025Only'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionText': questionText,
      'acceptableAnswers': acceptableAnswers,
      'voiceKeywords': voiceKeywords,
      'explanation': explanation,
      'section': section,
      'is2025Only': is2025Only,
    };
  }

  /// PROPRIETARY FUZZY LOGIC ENGINE
  /// Returns true if [userSpeech] contains at least one of the [voiceKeywords].
  /// Case-insensitive match.
  bool isSpokenMatch(String userSpeech) {
    if (voiceKeywords.isEmpty) return false;
    
    final normalizedInput = userSpeech.toLowerCase();
    
    for (final keyword in voiceKeywords) {
      if (normalizedInput.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
