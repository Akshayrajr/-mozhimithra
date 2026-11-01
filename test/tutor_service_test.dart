import 'package:flutter_test/flutter_test.dart';
import 'package:learno/ai/firebase_tutor_service.dart';
import 'package:learno/ai/tutor_service.dart';
import 'package:learno/data/learning_profile.dart';

void main() {
  const profile = LearningProfile(
    uid: 'user-1',
    displayName: 'Anu',
    targetLanguage: 'Spanish',
    dailyGoalMinutes: 15,
    skillLevel: 'beginner',
    tutorLanguage: 'Malayalam',
  );

  test('sends speaking history through the Firebase callable', () async {
    late String functionName;
    late Map<String, Object?> request;
    final service = FirebaseTutorService(
      callFunction: (name, data) async {
        functionName = name;
        request = data;
        return {'reply': '¡Hola!'};
      },
    );

    final reply = await service.reply(
      profile: profile,
      mode: TutorMode.guidedLesson,
      scenario: 'meet a new friend',
      history: const [
        TutorTurn(role: 'assistant', content: 'Say hello aloud.'),
        TutorTurn(role: 'user', content: 'Hola.'),
      ],
    );

    expect(functionName, 'tutorReply');
    expect(reply, '¡Hola!');
    expect(request['task'], 'reply');
    expect(request['mode'], 'guidedLesson');
    expect(request['scenario'], 'meet a new friend');
    expect(request['profile'], {
      'targetLanguage': 'Spanish',
      'tutorLanguage': 'Malayalam',
      'skillLevel': 'beginner',
      'dailyGoalMinutes': 15,
    });
    expect(request['history'], [
      {'role': 'assistant', 'content': 'Say hello aloud.'},
      {'role': 'user', 'content': 'Hola.'},
    ]);
  });

  test(
    'sends Malayalam translation practice as its dedicated tutor mode',
    () async {
      late Map<String, Object?> request;
      final service = FirebaseTutorService(
        callFunction: (_, data) async {
          request = data;
          return {'reply': 'Say in Spanish: Quiero agua.'};
        },
      );

      await service.reply(
        profile: profile,
        mode: TutorMode.translationPractice,
        history: const [
          TutorTurn(role: 'user', content: 'Translate my Malayalam phrase.'),
        ],
      );

      expect(request['mode'], 'translationPractice');
    },
  );

  test('sends speaking activity context for tutor recommendations', () async {
    late Map<String, Object?> request;
    final service = FirebaseTutorService(
      callFunction: (_, data) async {
        request = data;
        return {'reply': 'Practice introducing yourself aloud.'};
      },
    );

    final recommendation = await service.recommendNextActivity(
      profile: profile,
      recentActivity: const ['Speaking lesson in Spanish: completed'],
    );

    expect(recommendation, 'Practice introducing yourself aloud.');
    expect(request['task'], 'recommendation');
    expect(request['recentActivity'], [
      'Speaking lesson in Spanish: completed',
    ]);
  });

  test('reports an invalid Firebase callable response', () async {
    final service = FirebaseTutorService(callFunction: (_, _) async => null);

    expect(
      () => service.reply(
        profile: profile,
        history: const [TutorTurn(role: 'user', content: 'Hola')],
      ),
      throwsA(isA<TutorServiceException>()),
    );
  });
}
