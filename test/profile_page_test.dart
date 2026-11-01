import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:learno/auth/profile_page.dart';
import 'package:learno/data/learning_profile.dart';

void main() {
  const profile = LearningProfile(
    uid: 'profile-test',
    displayName: 'Anu',
    targetLanguage: 'Hindi',
    tutorLanguage: 'Malayalam',
    dailyGoalMinutes: 15,
    skillLevel: 'beginner',
  );

  testWidgets('saves profile details and a selected photo', (tester) async {
    String? savedName;
    String? savedLanguage;
    XFile? savedPhoto;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          profile: profile,
          photoPicker: () async => XFile.fromData(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aN8AAAAASUVORK5CYII=',
            ),
            path: 'avatar.png',
            mimeType: 'image/png',
          ),
          onSave:
              ({
                required displayName,
                required targetLanguage,
                required tutorLanguage,
                required dailyGoalMinutes,
                required skillLevel,
                photo,
                required removePhoto,
              }) async {
                savedName = displayName;
                savedLanguage = targetLanguage;
                savedPhoto = photo;
                return LearningProfile(
                  uid: profile.uid,
                  displayName: displayName,
                  targetLanguage: targetLanguage,
                  tutorLanguage: tutorLanguage,
                  dailyGoalMinutes: dailyGoalMinutes,
                  skillLevel: skillLevel,
                );
              },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      'Anu Nair',
    );
    await tester.tap(find.byKey(const ValueKey('profile-photo-button')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-profile-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-profile-button')));
    await tester.pumpAndSettle();

    expect(savedName, 'Anu Nair');
    expect(savedLanguage, 'Hindi');
    expect(savedPhoto?.name, 'avatar.png');
  });

  testWidgets('requires a profile name before saving', (tester) async {
    var saved = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          profile: profile,
          onSave:
              ({
                required displayName,
                required targetLanguage,
                required tutorLanguage,
                required dailyGoalMinutes,
                required skillLevel,
                photo,
                required removePhoto,
              }) async {
                saved = true;
                return profile;
              },
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('profile-name-field')),
      '',
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('save-profile-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-profile-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(saved, isFalse);
  });
}
