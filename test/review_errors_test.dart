import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citizen128/src/services/stats_service.dart';
import 'package:citizen128/src/ui/screens/review_errors_screen.dart';

void main() {
  testWidgets('ReviewErrorsScreen shows error message when no errors', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    await tester.pumpWidget(const MaterialApp(home: ReviewErrorsScreen()));
    await tester.pumpAndSettle();

    expect(find.text("No errors found!"), findsOneWidget);
  });

  test('StatsService adds and removes incorrect IDs', () async {
    SharedPreferences.setMockInitialValues({});
    
    await StatsService.addIncorrect('2025_q01');
    var ids = await StatsService.getIncorrectIds();
    expect(ids, contains('2025_q01'));

    await StatsService.removeIncorrect('2025_q01');
    ids = await StatsService.getIncorrectIds();
    expect(ids, isEmpty);
  });
}
