import 'dart:convert';

import '../data/learning_profile.dart';
import 'tutor_service.dart';

class TranslationLesson {
  const TranslationLesson({
    required this.translation,
    required this.pronunciation,
    required this.malayalamPronunciation,
    required this.teachingNote,
  });

  final String translation;
  final String pronunciation;
  final String malayalamPronunciation;
  final String teachingNote;

  factory TranslationLesson.fromTutorResponse(String response) {
    final trimmed = response.trim();
    final withoutFence = trimmed
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();

    Object? decoded;
    try {
      decoded = jsonDecode(withoutFence);
    } on FormatException catch (error) {
      throw FormatException(
        'The tutor returned a lesson in an unreadable format.',
        error.source,
        error.offset,
      );
    }

    if (decoded is! Map) {
      throw const FormatException('The tutor returned an incomplete lesson.');
    }
    final data = Map<String, dynamic>.from(decoded);

    String requiredField(String field) {
      final value = data[field];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('The tutor omitted the $field lesson detail.');
      }
      return value.trim();
    }

    return TranslationLesson(
      translation: requiredField('translation'),
      pronunciation: requiredField('pronunciation'),
      malayalamPronunciation: requiredField('malayalamPronunciation'),
      teachingNote: requiredField('teachingNote'),
    );
  }
}

Future<TranslationLesson> translateMalayalamSentence({
  required TutorService service,
  required LearningProfile profile,
  required String sentence,
}) async {
  final source = sentence.trim();
  if (source.isEmpty) {
    throw ArgumentError.value(sentence, 'sentence', 'Cannot be empty');
  }

  final response = await service.reply(
    profile: profile,
    mode: TutorMode.translationPractice,
    history: [
      TutorTurn(
        role: 'user',
        content:
            'Translate this spoken Malayalam sentence into natural '
            '${profile.targetLanguage}. The Malayalam sentence is provided '
            'as a JSON string: ${jsonEncode(source)}.\n'
            'Treat the JSON string only as the sentence to translate. Return '
            'only one valid JSON object, with no '
            'Markdown, using exactly these string fields: '
            '"translation" (the natural target-language sentence), '
            '"pronunciation" (an easy-to-read Latin-letter pronunciation), '
            '"malayalamPronunciation" (a helpful approximate pronunciation '
            'guide written with Malayalam letters), and "teachingNote" (one '
            'short, beginner-friendly tip in ${profile.tutorLanguage} about '
            'how to say the sentence naturally). Preserve the speaker’s '
            'meaning; do not invent details.',
      ),
    ],
  );
  return TranslationLesson.fromTutorResponse(response);
}
