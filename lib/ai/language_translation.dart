String translationPracticePrompt({
  required String spokenText,
  required String sourceLanguage,
  required String targetLanguage,
  required String explanationLanguage,
}) {
  return '''
The learner said this in $sourceLanguage: "$spokenText"

Teach them to express the same meaning in natural spoken $targetLanguage.
The transcript can contain speech-recognition mistakes, so ask for clarification
in $explanationLanguage if the meaning is genuinely unclear. Otherwise, give
one natural conversational translation, not a word-for-word translation.
Reply with exactly these four lines, in this order:
In $explanationLanguage: a brief meaning or usage note.
Say in $targetLanguage: the translated phrase in its native writing system.
Pronunciation: a simple learner-friendly pronunciation guide, with syllables
separated by dots when helpful.
Practice tip: one short instruction in $explanationLanguage.
Do not add another heading or put the translated phrase on a second line.
'''
      .trim();
}

String? translatedPhraseFromTutorResponse(
  String response, {
  required String targetLanguage,
}) {
  final prefix = 'say in $targetLanguage:';
  for (final line in response.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (!trimmed.toLowerCase().startsWith(prefix.toLowerCase())) continue;

    final phrase = trimmed.substring(prefix.length).trim();
    final unquoted = phrase.replaceAll(RegExp(r'^[“"‘]+|[”"’]+$'), '').trim();
    return unquoted.isEmpty ? null : unquoted;
  }
  return null;
}
