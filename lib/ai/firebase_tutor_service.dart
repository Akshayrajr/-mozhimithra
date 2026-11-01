import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

import '../data/learning_profile.dart';
import 'tutor_service.dart';

typedef FirebaseFunctionCall =
    Future<Object?> Function(String name, Map<String, Object?> data);

class FirebaseTutorService implements TutorService {
  FirebaseTutorService({FirebaseFunctionCall? callFunction})
    : _callFunction = callFunction ?? _callFirebaseFunction;

  final FirebaseFunctionCall _callFunction;

  @override
  bool get isConfigured => true;

  @override
  Future<String> reply({
    required LearningProfile profile,
    required List<TutorTurn> history,
    TutorMode mode = TutorMode.conversation,
    String? scenario,
  }) {
    return _request({
      'task': 'reply',
      'profile': _profilePayload(profile),
      'mode': mode.name,
      'scenario': scenario,
      'history': [
        for (final turn in history)
          {'role': turn.role, 'content': turn.content},
      ],
    });
  }

  @override
  Future<String> recommendNextActivity({
    required LearningProfile profile,
    required List<String> recentActivity,
  }) {
    return _request({
      'task': 'recommendation',
      'profile': _profilePayload(profile),
      'recentActivity': recentActivity.take(12).toList(),
    });
  }

  Future<String> _request(Map<String, Object?> data) async {
    try {
      final result = await _callFunction('tutorReply', data);
      if (result is! Map || result['reply'] is! String) {
        throw const TutorServiceException(
          'The Firebase tutor returned an unreadable response.',
        );
      }
      final reply = (result['reply'] as String).trim();
      if (reply.isEmpty) {
        throw const TutorServiceException(
          'The Firebase tutor returned an empty response.',
        );
      }
      return reply;
    } on FirebaseFunctionsException catch (error) {
      throw TutorServiceException(_messageForCode(error.code));
    }
  }

  static Map<String, Object?> _profilePayload(LearningProfile profile) => {
    'targetLanguage': profile.targetLanguage,
    'tutorLanguage': profile.tutorLanguage,
    'skillLevel': profile.skillLevel,
    'dailyGoalMinutes': profile.dailyGoalMinutes,
  };

  static Future<Object?> _callFirebaseFunction(
    String name,
    Map<String, Object?> data,
  ) async {
    final functions = FirebaseFunctions.instanceFor(
      app: Firebase.app(),
      region: 'asia-south1',
    );
    final response = await functions.httpsCallable(name).call(data);
    return response.data;
  }

  static String _messageForCode(String code) => switch (code) {
    'unauthenticated' =>
      'Sign in again to continue using your tutor.',
    'resource-exhausted' => 'The tutor is busy. Wait a minute and try again.',
    'failed-precondition' =>
      'The tutor backend is not configured for this service yet.',
    'invalid-argument' => 'The tutor request was invalid. Please retry.',
    'unavailable' => 'Tutor is temporarily unavailable. Try again shortly.',
    _ => 'Could not reach the Firebase tutor. Please try again.',
  };
}
