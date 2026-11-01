import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:learno/ai/voice_locale.dart';
import 'package:learno/data/vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_tts');

  test('maps Malayalam to its Indian locale', () {
    expect(localeCodeForLanguage('Malayalam'), 'ml-IN');
  });

  test('maps every supported learning language to its own speech locale', () {
    for (final language in supportedTargetLanguages) {
      final locale = localeCodeForLanguage(language);
      expect(locale, isNotEmpty, reason: '$language must have a speech locale');
      if (language != 'English') {
        expect(
          locale,
          isNot('en-US'),
          reason: '$language must not use English',
        );
      }
    }
  });

  test('rejects unknown languages instead of silently using English', () {
    expect(() => localeCodeForLanguage('Klingon'), throwsArgumentError);
  });

  test('prefers the requested installed locale', () {
    expect(availableTtsLocale('Malayalam', ['en-US', 'ml', 'ml-IN']), 'ml-IN');
  });

  test('uses another installed regional voice for the same language', () {
    expect(availableTtsLocale('Malayalam', ['en-US', 'ml-MY']), 'ml-MY');
  });

  test('does not silently select a voice from a different language', () {
    expect(availableTtsLocale('Malayalam', ['en-US', 'hi-IN']), isNull);
  });

  test('configures Malayalam using the installed matching voice', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getLanguages' => ['en-US', 'ml'],
            'setLanguage' => 1,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final locale = await setAvailableTtsLanguage(FlutterTts(), 'Malayalam');

    expect(locale, 'ml');
    expect(calls.map((call) => call.method), ['getLanguages', 'setLanguage']);
    expect(calls.last.arguments, 'ml');
  });

  test(
    'does not configure another language when Malayalam is unavailable',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return call.method == 'getLanguages' ? ['en-US', 'hi-IN'] : 1;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final locale = await setAvailableTtsLanguage(FlutterTts(), 'Malayalam');

      expect(locale, isNull);
      expect(calls.map((call) => call.method), ['getLanguages']);
    },
  );

  test(
    'reports a platform rejection of the selected Malayalam voice',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'getLanguages' => ['ml-IN'],
              'setLanguage' => 0,
              _ => null,
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );

      final locale = await setAvailableTtsLanguage(FlutterTts(), 'Malayalam');

      expect(locale, isNull);
    },
  );
}
