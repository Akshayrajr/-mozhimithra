import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

abstract interface class SpeechAudioService {
  Future<void> speak({required String text, required String language});

  Future<void> stop();

  Future<void> dispose();
}

class FirebaseSpeechAudioService implements SpeechAudioService {
  FirebaseSpeechAudioService({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> speak({
    required String text,
    required String language,
  }) async {
    final functions = FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: 'asia-south1',
    );
    final response = await functions.httpsCallable('synthesizeSpeech').call({
      'text': text,
      'language': language,
    });
    final data = response.data;
    if (data is! Map || data['audioContent'] is! String) {
      throw const FormatException('Speech function returned invalid audio.');
    }

    final audioBytes = base64Decode(data['audioContent'] as String);
    if (audioBytes.isEmpty) {
      throw const FormatException('Speech function returned empty audio.');
    }

    final completion = _player.onPlayerComplete.first.timeout(
      const Duration(seconds: 90),
    );
    await _player.play(BytesSource(audioBytes, mimeType: 'audio/wav'));
    await completion;
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
