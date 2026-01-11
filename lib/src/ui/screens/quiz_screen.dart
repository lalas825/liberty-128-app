import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../logic/viewmodels/quiz_viewmodel.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  static const Color federalBlue = Color(0xFF112D50);
  static const Color libertyGreen = Color(0xFF00C4B4);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => QuizViewModel(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: federalBlue,
          title: Text(
            'Study Mode',
            style: GoogleFonts.publicSans(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Consumer<QuizViewModel>(
          builder: (context, model, child) {
            if (model.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (model.totalQuestions == 0 && !model.isLoading) { // Optional safety check
               return const Center(child: Text("Failed to load questions."));
            }
            
            return Column(
              children: [
                // Top: Progress
                LinearProgressIndicator(
                  value: (model.currentQuestionIndex + 1) / model.totalQuestions,
                  backgroundColor: Colors.grey[300],
                  color: libertyGreen,
                  minHeight: 6,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${model.currentQuestionIndex + 1}/${model.totalQuestions}',
                        style: GoogleFonts.publicSans(
                          color: federalBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Score: ${model.score}',
                        style: GoogleFonts.publicSans(
                          color: federalBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Center: Question
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Center(
                      child: Text(
                        model.currentQuestion['question'],
                        textAlign: TextAlign.center,
                        style: GoogleFonts.publicSans(
                          color: federalBlue,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Bottom: Options
                Container(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      ...(model.currentQuestion['options'] as List<String>).map((option) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _OptionButton(
                            text: option,
                            isSelected: model.selectedAnswer == option,
                            isCorrect: option == model.currentQuestion['answer'],
                            isAnswered: model.isAnswered,
                            onTap: () => model.answerQuestion(option),
                          ),
                        );
                      }).toList(),
                      
                      const SizedBox(height: 16),
                      
                      // Next Button (Only visible if answered)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: model.isAnswered
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: federalBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => model.nextQuestion(context),
                                child: Text(
                                  model.currentQuestionIndex < model.totalQuestions - 1 
                                      ? 'Next Question' 
                                      : 'Finish Quiz',
                                  style: GoogleFonts.publicSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Helper Widget for Clean Code
class _OptionButton extends StatelessWidget {
  final String text;
  final bool isSelected;
  final bool isCorrect;
  final bool isAnswered;
  final VoidCallback onTap;

  const _OptionButton({
    required this.text,
    required this.isSelected,
    required this.isCorrect,
    required this.isAnswered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic Color Logic
    Color getBackgroundColor() {
      if (!isAnswered) return Colors.white;
      if (isSelected && isCorrect) return const Color(0xFFE0F7FA); // Light Green tint
      if (isSelected && !isCorrect) return const Color(0xFFFFEBEE); // Light Red tint
      if (isCorrect && !isSelected) return const Color(0xFFE0F7FA); // Show correct answer
      return Colors.white;
    }

    Color getBorderColor() {
      if (!isAnswered) return Colors.grey.shade300;
      if (isSelected && isCorrect) return const Color(0xFF00C4B4); // Green
      if (isSelected && !isCorrect) return Colors.red; // Red
      if (isCorrect && !isSelected) return const Color(0xFF00C4B4); // Show correct answer
      return Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.publicSans(
                  color: const Color(0xFF112D50),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isAnswered && (isSelected || isCorrect))
              Icon(
                (isSelected && isCorrect) || (!isSelected && isCorrect) 
                    ? Icons.check_circle 
                    : Icons.cancel,
                color: (isSelected && isCorrect) || (!isSelected && isCorrect)
                    ? const Color(0xFF00C4B4) 
                    : Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}
