import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learno/ai/recommendation_sheet.dart';
import 'package:learno/ai/tutor_service.dart';
import 'package:learno/data/learning_profile.dart';

void main() {
  testWidgets('recommendation starts a guided lesson', (tester) async {
    const profile = LearningProfile(
      uid: 'user-1',
      displayName: 'Anu',
      targetLanguage: 'Spanish',
      dailyGoalMinutes: 15,
      skillLevel: 'beginner',
    );
    final service = _FakeTutorService();
    var guidedLessonRequested = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final startLesson = await showModalBottomSheet<bool>(
                  context: context,
                  builder: (context) => RecommendationSheet(
                    profile: profile,
                    service: service,
                    loadRecentActivity: () async => const [
                      'Speaking lesson in Spanish: needs more practice',
                    ],
                  ),
                );
                guidedLessonRequested = startLesson == true;
              },
              child: const Text('Open recommendation'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open recommendation'));
    await tester.pumpAndSettle();
    expect(find.text('Review greetings next.'), findsOneWidget);
    expect(service.recentActivity, [
      'Speaking lesson in Spanish: needs more practice',
    ]);

    await tester.tap(find.text('Start guided lesson'));
    await tester.pumpAndSettle();
    expect(guidedLessonRequested, isTrue);
  });
}

class _FakeTutorService implements TutorService {
  List<String>? recentActivity;

  @override
  bool get isConfigured => true;

  @override
  Future<String> reply({
    required LearningProfile profile,
    required List<TutorTurn> history,
    TutorMode mode = TutorMode.conversation,
    String? scenario,
  }) async => 'Lets begin.';

  @override
  Future<String> recommendNextActivity({
    required LearningProfile profile,
    required List<String> recentActivity,
  }) async {
    this.recentActivity = recentActivity;
    return 'Review greetings next.';
  }
}
