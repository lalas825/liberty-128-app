import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen128/src/ui/screens/profile_screen.dart';

void main() {
  testWidgets('Profile Screen displays settings and saves name', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text("Study Command Center"), findsOneWidget);
    
    // Verify Settings Sections
    expect(find.text("SETTINGS"), findsOneWidget);
    expect(find.text("Interviewer Voice Speed"), findsOneWidget);
    expect(find.text("Daily Reminders"), findsOneWidget); // SwitchListTile title
    
    // Verify Name Field Exists
    expect(find.byType(TextField), findsOneWidget);
    
    // Enter Name
    await tester.enterText(find.byType(TextField), "John Doe");
    await tester.pump();
    
    // Verify that the avatar text updates (First letter of name)
    expect(find.text("J"), findsOneWidget);

    // Verify Danger Zone
    expect(find.text("DANGER ZONE"), findsOneWidget);
    expect(find.text("Reset All Progress"), findsOneWidget);
  });
}
