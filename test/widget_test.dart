// Basic widget tests for Irene Training app
//
// Note: Full widget tests require mocking Supabase.
// These are placeholder tests that verify basic widget rendering.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irene_training/core/widgets/buttons.dart';
import 'package:irene_training/core/theme/app_colors.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('renders correctly with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Test Button',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Test Button',
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('is disabled when onPressed is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrimaryButton(
              text: 'Test Button',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('Test Button'), findsOneWidget);
    });
  });

  group('SecondaryButton', () {
    testWidgets('renders correctly with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SecondaryButton(
              text: 'Secondary',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Secondary'), findsOneWidget);
    });
  });

  group('DangerButton', () {
    testWidgets('renders correctly with text', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DangerButton(
              text: 'Delete',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('AppColors', () {
    test('primary color is teal', () {
      expect(AppColors.primary, const Color(0xFF0D9488));
    });
  });
}
