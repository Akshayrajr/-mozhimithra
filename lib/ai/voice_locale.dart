/// Maps the app's supported language names to BCP-47 locale identifiers used
/// by speech recognition and text-to-speech on Android/iOS.
///
/// A single code is shared by both features: the learner speaks and listens in
/// their target language, while tutor explanations are written in a tutor
/// language that is also covered here.
library;

import 'package:flutter_tts/flutter_tts.dart';

const Map<String, String> _localeCodes = {
  // Target languages
  'Arabic': 'ar-SA',
  'Assamese': 'as-IN',
  'Bengali': 'bn-IN',
  'English': 'en-US',
  'French': 'fr-FR',
  'German': 'de-DE',
  'Gujarati': 'gu-IN',
  'Hindi': 'hi-IN',
  'Japanese': 'ja-JP',
  'Kannada': 'kn-IN',
  'Korean': 'ko-KR',
  'Malayalam': 'ml-IN',
  'Mandarin Chinese': 'zh-CN',
  'Marathi': 'mr-IN',
  'Odia': 'or-IN',
  'Punjabi': 'pa-IN',
  'Spanish': 'es-ES',
  'Tamil': 'ta-IN',
  'Telugu': 'te-IN',
  'Urdu': 'ur-PK',
};

/// Returns a BCP-47 locale identifier for [language].
///
/// Unknown names are rejected rather than silently using an English voice.
String localeCodeForLanguage(String language) {
  final locale = _localeCodes[language];
  if (locale == null) {
    throw ArgumentError.value(language, 'language', 'Unsupported language');
  }
  return locale;
}

/// Picks a locale that the installed TTS engine reports as available.
///
/// Prefer the configured region (for example `ml-IN`), then another installed
/// regional voice for that language. Returns null when no matching voice exists.
String? availableTtsLocale(String language, Iterable<String> availableLocales) {
  final requested = localeCodeForLanguage(language).toLowerCase();
  final baseLanguage = requested.split('-').first;
  final locales = availableLocales
      .map((locale) => locale.replaceAll('_', '-'))
      .toList(growable: false);

  for (final locale in locales) {
    if (locale.toLowerCase() == requested) return locale;
  }
  for (final locale in locales) {
    if (locale.toLowerCase() == baseLanguage) return locale;
  }
  for (final locale in locales) {
    if (locale.toLowerCase().startsWith('$baseLanguage-')) return locale;
  }
  return null;
}

/// Configures [tts] to use the best installed voice for [language].
///
/// Returns the selected locale, or null if the engine has no voice for the
/// requested language.
Future<String?> setAvailableTtsLanguage(FlutterTts tts, String language) async {
  final installedLocales = await tts.getLanguages;
  if (installedLocales is! List) return null;

  final locale = availableTtsLocale(
    language,
    installedLocales.whereType<String>(),
  );
  if (locale == null) return null;

  final result = await tts.setLanguage(locale);
  if (result == false || result == 0) return null;
  return locale;
}
