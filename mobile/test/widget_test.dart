import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/screens/onboarding_screen.dart';

void main() {
  testWidgets('OnboardingScreen smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    // Verify that the first page is shown
    expect(find.text('Bienvenue sur FamilyGuard'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    
    // Tap the 'Suivant' button
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    
    // Verify that the second page is shown
    expect(find.text('Protégez vos enfants'), findsOneWidget);
  });
}
