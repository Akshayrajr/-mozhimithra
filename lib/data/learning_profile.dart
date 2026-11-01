import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class LearningProgressSummary {
  const LearningProgressSummary({
    this.completedChallenges = 0,
    this.completedToday = 0,
    this.currentStreakDays = 0,
    this.weeklyCompletions = const [0, 0, 0, 0, 0, 0, 0],
  });

  final int completedChallenges;
  final int completedToday;
  final int currentStreakDays;
  final List<int> weeklyCompletions;

  int get completionsThisWeek =>
      weeklyCompletions.fold(0, (total, eventCount) => total + eventCount);
}

class LearningProfile {
  const LearningProfile({
    required this.uid,
    required this.displayName,
    required this.targetLanguage,
    required this.dailyGoalMinutes,
    required this.skillLevel,
    this.tutorLanguage = 'Malayalam',
    this.profilePhotoPath,
  });

  final String uid;
  final String displayName;
  final String targetLanguage;
  final int dailyGoalMinutes;
  final String skillLevel;
  final String tutorLanguage;
  final String? profilePhotoPath;

  factory LearningProfile.fromDocument(
    String uid,
    String displayName,
    Map<String, dynamic> data,
  ) {
    return LearningProfile(
      uid: uid,
      displayName: displayName,
      targetLanguage: data['targetLanguage'] as String? ?? 'Hindi',
      dailyGoalMinutes: data['dailyGoalMinutes'] as int? ?? 15,
      skillLevel: data['skillLevel'] as String? ?? 'beginner',
      tutorLanguage: data['tutorLanguage'] as String? ?? 'Malayalam',
      profilePhotoPath: data['profilePhotoPath'] as String?,
    );
  }

  Map<String, Object> toDocument() => {
    'targetLanguage': targetLanguage,
    'dailyGoalMinutes': dailyGoalMinutes,
    'skillLevel': skillLevel,
    'tutorLanguage': tutorLanguage,
    if (profilePhotoPath != null) 'profilePhotoPath': profilePhotoPath!,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class LearningProfileRepository {
  LearningProfileRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore =
           firestore ??
           FirebaseFirestore.instanceFor(
             app: (auth ?? FirebaseAuth.instance).app,
             databaseId: 'default',
           ),
       _auth = auth ?? FirebaseAuth.instance,
       _storage =
           storage ??
           FirebaseStorage.instanceFor(
             app: (auth ?? FirebaseAuth.instance).app,
           );

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _profileRef(String uid) =>
      _firestore.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _eventsRef(String uid) =>
      _profileRef(uid).collection('learningEvents');

  Future<LearningProfile> loadOrCreate(User user) {
    final reference = _profileRef(user.uid);
    final displayName = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : 'Learner';

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (snapshot.exists) {
        final data = snapshot.data()!;
        if (!data.containsKey('tutorLanguage')) {
          transaction.update(reference, {
            'tutorLanguage': 'Malayalam',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        return LearningProfile.fromDocument(user.uid, displayName, data);
      }

      const profile = LearningProfile(
        uid: '',
        displayName: '',
        targetLanguage: 'Hindi',
        dailyGoalMinutes: 15,
        skillLevel: 'beginner',
      );
      transaction.set(reference, profile.toDocument());
      return LearningProfile(
        uid: user.uid,
        displayName: displayName,
        targetLanguage: profile.targetLanguage,
        dailyGoalMinutes: profile.dailyGoalMinutes,
        skillLevel: profile.skillLevel,
      );
    });
  }

  Future<LearningProfile> updatePreferences(
    LearningProfile profile, {
    String? targetLanguage,
    int? dailyGoalMinutes,
    String? skillLevel,
    String? tutorLanguage,
  }) async {
    final updates = <String, Object>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (dailyGoalMinutes != null) 'dailyGoalMinutes': dailyGoalMinutes,
      if (skillLevel != null) 'skillLevel': skillLevel,
      if (tutorLanguage != null) 'tutorLanguage': tutorLanguage,
    };
    await _profileRef(profile.uid).update(updates);

    return LearningProfile(
      uid: profile.uid,
      displayName: profile.displayName,
      targetLanguage: targetLanguage ?? profile.targetLanguage,
      dailyGoalMinutes: dailyGoalMinutes ?? profile.dailyGoalMinutes,
      skillLevel: skillLevel ?? profile.skillLevel,
      tutorLanguage: tutorLanguage ?? profile.tutorLanguage,
      profilePhotoPath: profile.profilePhotoPath,
    );
  }

  Future<LearningProfile> updateProfile(
    LearningProfile profile, {
    required String displayName,
    required String targetLanguage,
    required String tutorLanguage,
    required int dailyGoalMinutes,
    required String skillLevel,
    XFile? photo,
    bool removePhoto = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != profile.uid) {
      throw StateError('The signed-in user does not match this profile.');
    }

    String? nextPhotoPath = profile.profilePhotoPath;
    var uploadedPhoto = false;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw ArgumentError('Choose an image smaller than 5 MB.');
      }
      final extension = photo.name.split('.').last.toLowerCase();
      final contentType =
          photo.mimeType ??
          switch (extension) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => null,
          };
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(contentType)) {
        throw ArgumentError('Choose a JPG, PNG, or WebP image.');
      }
      nextPhotoPath =
          'users/${profile.uid}/profile/avatar_${DateTime.now().microsecondsSinceEpoch}';
      await _storage
          .ref(nextPhotoPath)
          .putData(bytes, SettableMetadata(contentType: contentType));
      uploadedPhoto = true;
    } else if (removePhoto) {
      nextPhotoPath = null;
    }

    final reference = _profileRef(profile.uid);
    final previousName = user.displayName;
    var nameUpdated = false;
    try {
      if (previousName != displayName.trim()) {
        await user.updateDisplayName(displayName.trim());
        nameUpdated = true;
      }
      await reference.update({
        'targetLanguage': targetLanguage,
        'tutorLanguage': tutorLanguage,
        'dailyGoalMinutes': dailyGoalMinutes,
        'skillLevel': skillLevel,
        'updatedAt': FieldValue.serverTimestamp(),
        if (nextPhotoPath == null)
          'profilePhotoPath': FieldValue.delete()
        else
          'profilePhotoPath': nextPhotoPath,
      });
    } catch (error) {
      if (nameUpdated) {
        try {
          await user.updateDisplayName(previousName);
        } catch (rollbackError, stackTrace) {
          debugPrint('Profile name rollback failed: $rollbackError');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      if (uploadedPhoto && nextPhotoPath != null) {
        try {
          await _storage.ref(nextPhotoPath).delete();
        } catch (cleanupError, stackTrace) {
          debugPrint('Profile photo cleanup failed: $cleanupError');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      rethrow;
    }

    final previousPhotoPath = profile.profilePhotoPath;
    if (previousPhotoPath != null && previousPhotoPath != nextPhotoPath) {
      try {
        await _storage.ref(previousPhotoPath).delete();
      } catch (error, stackTrace) {
        debugPrint('Old profile photo cleanup failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return LearningProfile(
      uid: profile.uid,
      displayName: displayName.trim(),
      targetLanguage: targetLanguage,
      tutorLanguage: tutorLanguage,
      dailyGoalMinutes: dailyGoalMinutes,
      skillLevel: skillLevel,
      profilePhotoPath: nextPhotoPath,
    );
  }

  Future<String?> profilePhotoUrl(LearningProfile profile) async {
    final path = profile.profilePhotoPath;
    if (path == null) return null;
    return _storage.ref(path).getDownloadURL();
  }

  Future<List<String>> recentActivitySummary(LearningProfile profile) async {
    final snapshot = await _eventsRef(
      profile.uid,
    ).orderBy('createdAt', descending: true).limit(12).get();

    return snapshot.docs
        .where(
          (document) =>
              document.data()['exerciseType'] == 'guidedLesson' &&
              document.data()['targetLanguage'] == profile.targetLanguage,
        )
        .map((document) {
          final data = document.data();
          return 'Speaking lesson in ${profile.targetLanguage}: '
              '${data['correct'] == true ? 'completed successfully' : 'needs more practice'}';
        })
        .toList();
  }

  Future<LearningProgressSummary> loadProgressSummary(
    LearningProfile profile,
  ) async {
    final snapshot = await _eventsRef(
      profile.uid,
    ).orderBy('createdAt', descending: true).get();
    final today = _dateOnly(DateTime.now());
    final completionsByDay = <DateTime, int>{};
    var completedChallenges = 0;

    for (final document in snapshot.docs) {
      final data = document.data();
      if (data['targetLanguage'] != profile.targetLanguage ||
          data['correct'] != true ||
          data['exerciseType'] != 'guidedLesson') {
        continue;
      }

      final createdAt = data['createdAt'];
      final date = switch (createdAt) {
        Timestamp timestamp => _dateOnly(timestamp.toDate()),
        DateTime dateTime => _dateOnly(dateTime),
        _ => null,
      };
      if (date == null) continue;

      completedChallenges++;
      completionsByDay.update(
        date,
        (previousCount) => previousCount + 1,
        ifAbsent: () => 1,
      );
    }

    final weeklyCompletions = List<int>.generate(7, (index) {
      final date = today.subtract(Duration(days: 6 - index));
      return completionsByDay[date] ?? 0;
    }, growable: false);

    var streakDays = 0;
    var streakDay = completionsByDay.containsKey(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (completionsByDay.containsKey(streakDay)) {
      streakDays++;
      streakDay = streakDay.subtract(const Duration(days: 1));
    }

    return LearningProgressSummary(
      completedChallenges: completedChallenges,
      completedToday: completionsByDay[today] ?? 0,
      currentStreakDays: streakDays,
      weeklyCompletions: weeklyCompletions,
    );
  }

  Future<void> recordTutorLessonCompletion(LearningProfile profile) {
    return _eventsRef(profile.uid).add({
      'targetLanguage': profile.targetLanguage,
      'exerciseType': 'guidedLesson',
      'correct': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
