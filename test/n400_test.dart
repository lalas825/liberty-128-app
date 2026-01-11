import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen128/src/ui/screens/home_screen.dart';
import 'package:citizen128/src/ui/screens/n400_vocab_screen.dart';

void main() {
  testWidgets('Opens N-400 Vocab Screen and shows intro', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Tap N-400 Vocab Card
    await tester.tap(find.text("N-400 Vocab"));
    await tester.pumpAndSettle();

    // Verify Screen Title
    expect(find.text("N-400 Vocabulary"), findsOneWidget);

    // Verify we are on the N400VocabScreen type
    expect(find.byType(N400VocabScreen), findsOneWidget);
    
    // In test environment without assets, it likely shows loading or error.
    // We just want to ensure navigation happened.
  });
}
