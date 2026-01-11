import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liberty_128_app/src/ui/screens/home_screen.dart';

void main() {
  testWidgets('Daily Challenge Card shows streaks and state', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'daily_streak': 5,
    });
    
    // We need MediaQuery for the modal bottom sheet
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify "Daily Challenge" card is present and shows active state (not completed today)
    expect(find.text("Daily Challenge"), findsOneWidget);
    expect(find.text("Keep your streak alive!"), findsOneWidget);
    
    // NOTE: We cannot easily test the Quiz Dialog because it requires loading assets (JSON),
    // which fails in standard widget tests unless mocked via DefaultAssetBundle.
    // However, we can test the UI state changes if we could simulate completion, but that logic is internal.
  });
  
  testWidgets('Daily Challenge Card shows Completed state', (WidgetTester tester) async {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
    
    SharedPreferences.setMockInitialValues({
      'daily_streak': 10,
      'last_challenge_date': todayStr,
    });
    
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify Completed UI
    expect(find.text("Great Job!"), findsOneWidget);
    expect(find.text("Streak: 10 Days"), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
