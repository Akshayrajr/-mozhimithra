# Mozhi Mithram

A speaking-focused language-learning app built with Flutter and Firebase.

## Firebase Tutor Backend and Speech

The app calls authenticated Firebase callable functions in `asia-south1`. The
Functions backend in `functions/` proxies tutor requests to an
OpenAI-compatible provider and calls Google Cloud Text-to-Speech (Cloud TTS)
for spoken replies. Provider URL, API key, and model are Firebase Functions
secrets; they are never shipped in the app.

1. Enable the **Cloud Functions** and **Cloud Text-to-Speech** APIs for the
   Firebase project and ensure billing is enabled. The Functions runtime service
   account needs permission to call Cloud TTS.
2. From the project root, configure the provider values without putting them in
   source files:

   ```powershell
   firebase use mozhimithra
   firebase functions:secrets:set TUTOR_PROVIDER_URL
   firebase functions:secrets:set TUTOR_API_KEY
   firebase functions:secrets:set TUTOR_MODEL
   ```

   Use the provider's HTTPS chat-completions endpoint, API key, and model when
   prompted. Do not paste secrets into chat or commit them.
3. Deploy the Firebase Functions:

   ```powershell
   firebase deploy --only functions
   ```

Firebase Auth credentials are attached automatically to callable requests.
Functions reject unauthenticated callers and enforce per-user request limits.
Tutor requests include the selected languages, skill level, teaching mode, and
recent conversation turns. No `--dart-define` or separate tutor URL is needed.

Cloud TTS selects an available voice from Google's live voice catalog for each
target language. If a cloud voice is unavailable or the function cannot be
reached, the app falls back to the device's installed TTS voice. Some languages
or regional voices may not be available in either engine on every device. The
client does not silently substitute a different language.

Cloud TTS usage incurs charges under the Firebase project's linked Google Cloud
billing account. Functions limit each signed-in user to 12 tutor requests and
30 speech synthesis requests per minute.

## Profile and Photos

The account menu on any learning tab opens the profile editor. Learners can
update their display name, learning and explanation languages, speaking level,
and daily goal, and add or remove a profile photo. Photos are resized before
upload where the platform supports resizing, limited to 5 MB, and stored in the
signed-in user's Firebase Storage folder. Firestore stores the photo's storage
path rather than its download URL.

Enable Firebase Storage and deploy both the Firestore and Storage rules after
selecting the project's Storage bucket:

```powershell
firebase deploy --only firestore:rules,storage
```

Only the authenticated owner can read or change their profile photo. Storage
rules accept JPG, PNG, and WebP images up to 5 MB.

## Speaking Workflow

On the Practice tab, **Guided speaking lesson** starts voice-first practice.
The tutor reads its opening prompt, listens for the learner's response, sends
recognized speech to the Firebase tutor function, then speaks its reply and
listens for the next turn. **Role-play** offers everyday conversation practice;
**Speak & repeat** models target-language phrases and lets the learner practice
aloud.

Voice input requires microphone and speech-recognition permissions. Android
and iOS permission declarations are included in the platform projects.
Speech recognition remains device-provided; cloud TTS provides tutor replies
and pronunciation examples.

The Voice Trainer's percentage is a match between the intended phrase and the
speech-recognition transcript. It is not an acoustic pronunciation or accent
score.

Speech recognition and device TTS availability varies by device, operating
system, installed language packs, and network access. The app asks the device
for the selected language and reports when voice input or a matching voice is
unavailable; it does not silently switch to English. System text scaling and
screen-reader settings are supported for accessibility.

## Progression

Learning is focused on speaking: guided voice lessons, natural conversation
role-play, and listen-and-repeat pronunciation practice. Guided practice counts
as complete after three learner replies receive tutor responses; this tracks
practice, not verified mastery or native-level fluency. Only completed guided
speaking lessons advance the challenge path. The Learn and Progress tabs show
speaking lesson counts and streaks for the selected language. Older writing and
vocabulary events remain in Firestore for compatibility but are not active
learning activities.

## Android release signing

Release builds must be signed with the app owner's private upload key; debug
signing is never used for release builds. Create `android/key.properties` (it is
git-ignored) with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`.
Keep the keystore and passwords private and backed up securely. Without all four
values, Android release output is unsigned and is not ready to publish.
