import '../models/civics_question_model.dart';

class Questions2025Seed {
  static const List<CivicsQuestion> data = [
    CivicsQuestion(
      id: '2025_q001',
      questionText: 'What is the supreme law of the land?',
      acceptableAnswers: ['The Constitution'],
      voiceKeywords: ['Constitution'],
      explanation: 'The Constitution sets up the government and protects basic rights of Americans.',
      section: 'Principles of American Democracy',
      is2025Only: false,
    ),
    CivicsQuestion(
      id: '2025_q002',
      questionText: 'What does the Constitution do?',
      acceptableAnswers: [
        'Sets up the government',
        'Defines the government',
        'Protects basic rights of Americans'
      ],
      voiceKeywords: ['Sets', 'Defines', 'Protects', 'Government', 'Rights'],
      explanation: 'It creates the framework for the federal government.',
      section: 'Principles of American Democracy',
      is2025Only: false,
    ),
    CivicsQuestion(
      id: '2025_q003',
      questionText: 'The idea of self-government is in the first three words of the Constitution. What are these words?',
      acceptableAnswers: ['We the People'],
      voiceKeywords: ['We', 'People'],
      explanation: 'It means the government receives its power from the people.',
      section: 'Principles of American Democracy',
      is2025Only: false,
    ),
    CivicsQuestion(
      id: '2025_q004',
      questionText: 'What is an amendment?',
      acceptableAnswers: [
        'A change (to the Constitution)',
        'An addition (to the Constitution)'
      ],
      voiceKeywords: ['Change', 'Addition'],
      explanation: 'It allows the Constitution to adapt over time.',
      section: 'Principles of American Democracy',
      is2025Only: true,
    ),
    CivicsQuestion(
      id: '2025_q005',
      questionText: 'What do we call the first ten amendments to the Constitution?',
      acceptableAnswers: ['The Bill of Rights'],
      voiceKeywords: ['Bill', 'Rights'],
      explanation: 'These amendments list specific prohibitions on governmental power.',
      section: 'Principles of American Democracy',
      is2025Only: true,
    ),
  ];
}
