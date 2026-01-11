import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen128/src/ui/screens/home_screen.dart';

void main() {
  testWidgets('Navigation switches tabs correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // Verify initial tab is Dashboard
    expect(find.text("Dashboard"), findsWidgets); // Used in Title and Tab Label

    // Tap Study Tab
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();

    // Verify Study Screen (Flashcards) is shown
    // "Flashcards" is the AppBar title of StudyScreen
    expect(find.text("Flashcards"), findsOneWidget);

    // Tap Profile Tab
    await tester.tap(find.byIcon(Icons.person));
    await tester.pumpAndSettle();

    // Verify Profile Screen
    expect(find.text("Profile"), findsWidgets); // Title and Tab Label
  });
}
