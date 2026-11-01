import '../data/learning_profile.dart';

class TutorTurn {
  const TutorTurn({required this.role, required this.content});

  final String role;
  final String content;
}

enum TutorMode { conversation, guidedLesson, rolePlay, translationPractice }

abstract interface class TutorService {
  bool get isConfigured;

  Future<String> reply({
    required LearningProfile profile,
    required List<TutorTurn> history,
    TutorMode mode = TutorMode.conversation,
    String? scenario,
  });

  Future<String> recommendNextActivity({
    required LearningProfile profile,
    required List<String> recentActivity,
  });
}

class TutorServiceException implements Exception {
  const TutorServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
