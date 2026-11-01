import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learno/ai/translation_lesson.dart';
import 'package:learno/ai/speech_audio_service.dart';
import 'package:learno/ai/tutor_service.dart';
import 'package:learno/ai/voice_trainer.dart';
import 'package:learno/data/learning_profile.dart';

void main() {
  const profile = LearningProfile(
    uid: 'learner-1',
    displayName: 'Anu',
    targetLanguage: 'Spanish',
    dailyGoalMinutes: 15,
    skillLevel: 'beginner',
    tutorLanguage: 'Malayalam',
  );
  const response =
      '{"translation":"Tengo hambre.","pronunciation":"TEN-go AM-breh",'
      '"malayalamPronunciation":"ടെംഗോ ആംബ്രെ",'
      '"teachingNote":"Tengo ഉപയോഗിച്ച് തുടങ്ങൂ."}';

  test('requests a Malayalam-to-target-language speaking lesson', () async {
    final service = _FakeTutorService(response);

    final lesson = await translateMalayalamSentence(
      service: service,
      profile: profile,
      sentence: ' എനിക്ക് വിശക്കുന്നു ',
    );

    expect(lesson.translation, 'Tengo hambre.');
    expect(lesson.pronunciation, 'TEN-go AM-breh');
    expect(lesson.malayalamPronunciation, 'ടെംഗോ ആംബ്രെ');
    expect(lesson.teachingNote, 'Tengo ഉപയോഗിച്ച് തുടങ്ങൂ.');
    expect(service.lastProfile?.targetLanguage, 'Spanish');
    expect(service.lastMode, TutorMode.translationPractice);
    expect(
      service.lastHistory?.single.content,
      contains('"എനിക്ക് വിശക്കുന്നു"'),
    );
    expect(service.lastHistory?.single.content, contains('valid JSON'));
  });

  test('reads translation lessons from fenced JSON', () {
    final lesson = TranslationLesson.fromTutorResponse(
      '```json\n$response\n```',
    );

    expect(lesson.translation, 'Tengo hambre.');
    expect(lesson.pronunciation, 'TEN-go AM-breh');
  });

  test('rejects malformed or incomplete tutor responses', () {
    expect(
      () => TranslationLesson.fromTutorResponse('I think you should say hola'),
      throwsFormatException,
    );
    expect(
      () => TranslationLesson.fromTutorResponse('{"translation":"Hola"}'),
      throwsFormatException,
    );
  });

  test('does not send an empty recognized sentence to the tutor', () async {
    final service = _FakeTutorService(response);
    await expectLater(
      translateMalayalamSentence(
        service: service,
        profile: profile,
        sentence: '   ',
      ),
      throwsArgumentError,
    );
  });

  testWidgets('voice trainer exposes Malayalam sentence practice', (
    tester,
  ) async {
    final service = _FakeTutorService(response);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceTrainerSheet(
            profile: profile,
            service: service,
            speechAudioService: _FakeSpeechAudioService(),
          ),
        ),
      ),
    );

    expect(find.text('Start speaking'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Say in Malayalam'));
    await tester.pump();

    expect(find.text('Speak naturally in Malayalam'), findsOneWidget);
    expect(find.text('Speak in Malayalam'), findsOneWidget);
    expect(find.text('Start speaking'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeTutorService implements TutorService {
  _FakeTutorService(this.response);

  final String response;
  LearningProfile? lastProfile;
  TutorMode? lastMode;
  List<TutorTurn>? lastHistory;

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
    lastMode = mode;
    lastHistory = history;
    return response;
  }

  @override
  Future<String> recommendNextActivity({
    required LearningProfile profile,
    required List<String> recentActivity,
  }) async => 'Practice a greeting next.';
}

class _FakeSpeechAudioService implements SpeechAudioService {
  @override
  Future<void> speak({required String text, required String language}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
