import 'package:flutter_test/flutter_test.dart';
import 'package:learno/ai/language_translation.dart';

void main() {
  group('translationPracticePrompt', () {
    test('asks the tutor to translate and teach the spoken phrase', () {
      final prompt = translationPracticePrompt(
        spokenText: 'എനിക്ക് വെള്ളം വേണം',
        sourceLanguage: 'Malayalam',
        targetLanguage: 'Spanish',
        explanationLanguage: 'Malayalam',
      );

      expect(prompt, contains('learner said this in Malayalam'));
      expect(prompt, contains('എനിക്ക് വെള്ളം വേണം'));
      expect(prompt, contains('natural spoken Spanish'));
      expect(prompt, contains('In Malayalam:'));
      expect(prompt, contains('Say in Spanish:'));
      expect(prompt, contains('Pronunciation:'));
      expect(prompt, contains('Practice tip:'));
    });
  });

  group('translatedPhraseFromTutorResponse', () {
    test('extracts the phrase from a case-insensitive labeled line', () {
      expect(
        translatedPhraseFromTutorResponse(
          'In Malayalam: A useful phrase.\n'
          'say in Spanish:  "Quiero agua, por favor."\n'
          'Pronunciation: kee-EH-roh AH-gwah',
          targetLanguage: 'Spanish',
        ),
        'Quiero agua, por favor.',
      );
    });

    test('returns null when the phrase is missing or empty', () {
      expect(
        translatedPhraseFromTutorResponse(
          'In Malayalam: Meaning.\nPronunciation: guide',
          targetLanguage: 'Spanish',
        ),
        isNull,
      );
      expect(
        translatedPhraseFromTutorResponse(
          'Say in Spanish:   \nPronunciation: guide',
          targetLanguage: 'Spanish',
        ),
        isNull,
      );
    });

    test('does not mistake another target-language label for a match', () {
      expect(
        translatedPhraseFromTutorResponse(
          'Say in French: Bonjour.',
          targetLanguage: 'Spanish',
        ),
        isNull,
      );
    });
  });
}
