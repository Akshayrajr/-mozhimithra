import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learno/ai/tutor_conversation_sheet.dart';
import 'package:learno/ai/tutor_service.dart';
import 'package:learno/data/learning_profile.dart';

void main() {
  testWidgets('personalizes the tutor chat and renders its reply', (
    tester,
  ) async {
    const profile = LearningProfile(
      uid: 'user-1',
      displayName: 'Anu',
      targetLanguage: 'Spanish',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    final service = _FakeTutorService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorConversationSheet(profile: profile, service: service),
        ),
      ),
    );

    expect(find.text('Your Spanish tutor'), findsOneWidget);
    expect(find.textContaining('Anu'), findsOneWidget);
    expect(find.byTooltip('Start voice conversation'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hola');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Great start. Now ask me how I am.'), findsOneWidget);
    expect(service.lastProfile?.targetLanguage, 'Spanish');
    expect(service.lastHistory?.last.content, 'Hola');
  });

  testWidgets('completes guided practice after three tutor turns', (
    tester,
  ) async {
    const profile = LearningProfile(
      uid: 'user-1',
      displayName: 'Anu',
      targetLanguage: 'Spanish',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    var completionRecorded = false;
    bool? nextChallengeRequested;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                nextChallengeRequested = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (context) => TutorConversationSheet(
                    profile: profile,
                    service: _FakeTutorService(),
                    mode: TutorMode.guidedLesson,
                    onLessonCompleted: () async {
                      completionRecorded = true;
                    },
                  ),
                );
              },
              child: const Text('Open tutor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open tutor'));
    await tester.pumpAndSettle();

    for (var turn = 0; turn < 3; turn++) {
      await tester.enterText(find.byType(TextField), 'Answer $turn');
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();
    }

    expect(completionRecorded, isTrue);
    expect(
      find.text('Practice complete! Your next lesson is ready.'),
      findsOneWidget,
    );
    expect(find.text('Next challenge'), findsOneWidget);
    await tester.tap(find.text('Next challenge'));
    await tester.pumpAndSettle();
    expect(nextChallengeRequested, isTrue);
  });

  testWidgets('chat sheet fits a narrow phone width', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const profile = LearningProfile(
      uid: 'user-1',
      displayName: 'Anu',
      targetLanguage: 'Mandarin Chinese',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorConversationSheet(
            profile: profile,
            service: _FakeTutorService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

class _FakeTutorService implements TutorService {
  LearningProfile? lastProfile;
  List<TutorTurn>? lastHistory;
  TutorMode? lastMode;

  @override
  bool get isConfigured => true;

  @override
  Future<String> reply({
    required LearningProfile profile,
    required List<TutorTurn> history,
    TutorMode mode = TutorMode.conversation,
    String? scenario,
  }) async {
    lastProfile = profile;
    lastHistory = history;
    lastMode = mode;
    return 'Great start. Now ask me how I am.';
  }

  @override
  Future<String> recommendNextActivity({
    required LearningProfile profile,
    required List<String> recentActivity,
  }) async => 'Review greetings next.';
}
