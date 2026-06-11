import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('SafeChildApp smoke test', (WidgetTester tester) async {
    // Build app — shows a loading spinner while checking auth
    await tester.pumpWidget(const SafeChildApp());
    await tester.pump();

    // The app renders without crashing
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
