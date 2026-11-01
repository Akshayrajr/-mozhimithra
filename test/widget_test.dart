// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learno/auth/auth_gate.dart';
import 'package:learno/data/learning_profile.dart';
import 'package:learno/main.dart';

void main() {
  testWidgets('shows intro and account entry points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IntroScreen(onCreateAccount: () {}, onSignIn: () {}),
      ),
    );

    expect(find.text('Mozhi Mithram'), findsOneWidget);
    expect(
      find.text(
        'Build confident, natural speech with a tutor that adapts to you.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('read, and write'), findsNothing);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('shows email sign-up fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthenticationScreen(createAccount: true, onBack: () {}),
      ),
    );

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('shows a speaking-focused personalized dashboard', (
    WidgetTester tester,
  ) async {
    const profile = LearningProfile(
      uid: 'test-user',
      displayName: 'Anu',
      targetLanguage: 'Hindi',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    await tester.pumpWidget(
      const MaterialApp(home: LearningHome(profile: profile)),
    );

    expect(find.text('Mozhi Mithram'), findsOneWidget);
    expect(find.textContaining(', Anu'), findsOneWidget);
    expect(find.text('SPEAKING COACH · PERSONALIZED PRACTICE'), findsOneWidget);
    expect(find.text('Continue lesson'), findsOneWidget);
    expect(find.text('Writing'), findsNothing);

    await tester.tap(find.text('Practice'));
    await tester.pumpAndSettle();

    expect(find.text('Guided speaking lesson'), findsOneWidget);
    expect(find.text('Natural conversation'), findsOneWidget);
    expect(find.text('Role-play a scene'), findsOneWidget);
    expect(find.text('Voice Trainer'), findsOneWidget);
    expect(find.text('Write a few words'), findsNothing);
    expect(find.text('Vocabulary flashcards'), findsNothing);
  });

  testWidgets('account menu offers profile editing', (tester) async {
    const profile = LearningProfile(
      uid: 'test-user',
      displayName: 'Anu',
      targetLanguage: 'Hindi',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    await tester.pumpWidget(
      const MaterialApp(home: LearningHome(profile: profile)),
    );

    await tester.tap(find.byTooltip('Account').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(
      find.text('Profile editing is unavailable right now.'),
      findsOneWidget,
    );
  });

  testWidgets('learning screens and sheets fit a narrow phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const profile = LearningProfile(
      uid: 'test-user',
      displayName: 'Anu',
      targetLanguage: 'Mandarin Chinese',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    await tester.pumpWidget(
      const MaterialApp(home: LearningHome(profile: profile)),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Continue lesson'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Continue lesson'));
    await tester.pumpAndSettle();
    final tutorLayoutError = tester.takeException();
    expect(
      tutorLayoutError,
      isNull,
      reason: tutorLayoutError is FlutterError
          ? tutorLayoutError.toStringDeep()
          : '$tutorLayoutError',
    );
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Practice'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Progress'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tutor language is independent from the learning language', (
    tester,
  ) async {
    const profile = LearningProfile(
      uid: 'test-user',
      displayName: 'Anu',
      targetLanguage: 'Spanish',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
      tutorLanguage: 'English',
    );
    await tester.pumpWidget(
      const MaterialApp(home: LearningHome(profile: profile)),
    );

    expect(find.text('Spanish'), findsOneWidget);
    expect(find.text('Explain in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('Explain in')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Malayalam').last);
    await tester.pumpAndSettle();

    expect(find.text('Spanish'), findsOneWidget);
    expect(find.text('Malayalam'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
