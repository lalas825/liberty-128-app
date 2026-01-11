import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:liberty_128_app/src/data/models/civics_question_model.dart';

void main() {
  test('Verify civics_questions_2025.json parsing', () async {
    final file = File('assets/civics_questions_2025.json');
    final jsonString = await file.readAsString();
    final List<dynamic> data = json.decode(jsonString);
    
    expect(data.isNotEmpty, true);
    
    for (var item in data) {
      try {
        final q = CivicsQuestion.fromJson(item);
        expect(q.id, isNotEmpty);
        expect(q.questionText, isNotEmpty);
      } catch (e) {
        fail('Failed to parse question: $item\nError: $e');
      }
    }
  });

  test('Verify civics_questions_2008.json parsing', () async {
    final file = File('assets/civics_questions_2008.json');
    final jsonString = await file.readAsString();
    final List<dynamic> data = json.decode(jsonString);
    
    expect(data.isNotEmpty, true);
    expect(data.length, 100, reason: '2008 version should have 100 questions');
    
    for (var item in data) {
      try {
        final q = CivicsQuestion.fromJson(item);
        expect(q.id, startsWith('2008_'), reason: 'ID should start with 2008_');
        expect(q.questionText, isNotEmpty);
      } catch (e) {
        fail('Failed to parse question: $item\nError: $e');
      }
    }
  });
}
