import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen128/src/ui/screens/home_screen.dart';
import 'package:citizen128/src/ui/screens/profile_screen.dart';

void main() {
  testWidgets('Dashboard shows countdown when date is set', (WidgetTester tester) async {
    // Setup Mock Prefs with a date
    final futureDate = DateTime.now().add(const Duration(days: 10));
    SharedPreferences.setMockInitialValues({
      'exam_date': futureDate.toIso8601String(),
    });
    
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify Countdown Card is present by finding the icon
    expect(find.byIcon(Icons.calendar_today), findsWidgets); // Might find 2 (one in card, one in settings)
    expect(find.textContaining("Days Until Interview"), findsOneWidget);
  });

  testWidgets('Reset logic clears preferences', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Test User',
      'exam_date': '2026-01-01T00:00:00.000',
    });
    
    // We need to provide the route table since reset uses pushNamedAndRemoveUntil
    await tester.pumpWidget(MaterialApp(
      home: const ProfileScreen(),
      routes: {
        '/onboarding': (context) => const Scaffold(body: Text("Onboarding Screen")),
      },
    ));
    await tester.pumpAndSettle();

    // Open Danger Zone Dialog
    final scrollFinder = find.byType(SingleChildScrollView);
    await tester.drag(scrollFinder, const Offset(0, -1000)); // Scroll down
    await tester.pumpAndSettle();
    
    final resetButton = find.text("Reset All Progress");
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    // Confirm Reset
    final confirmButton = find.text("Reset Everything");
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();
    
    // Verify Navigation to Onboarding
    expect(find.text("Onboarding Screen"), findsOneWidget);

    // Verify Prefs Cleared
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('user_name'), false);
    expect(prefs.containsKey('exam_date'), false);
  });
}
