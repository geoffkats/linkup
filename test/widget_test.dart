// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:linkup/main.dart';

void main() {
  testWidgets('LinkUp landing screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('LinkUp Uganda'), findsOneWidget);
    expect(find.text('Continue as Job Seeker'), findsOneWidget);
    expect(find.text('Continue as Employer'), findsOneWidget);
    expect(find.text('Continue as Admin'), findsOneWidget);
  });
}
