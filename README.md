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
aloud. **Say it in Malayalam** lets learners speak a phrase in Malayalam and
receive a natural target-language translation, a meaning note, pronunciation
guidance, and a short practice tip. The translated phrase can be played with
the target-language speech voice. This feature requires a live tutor backend
that supports the translation-practice response format.

Voice input requires microphone and speech-recognition permissions. Android
and iOS permission declarations are included in the platform projects.
Speech recognition remains device-provided; cloud TTS provides tutor replies
and pronunciation examples.

The Voice Trainer's percentage is a match between the intended phrase and the
speech-recognition transcript. It is not an acoustic pronunciation or accent
score.

## Local Firebase emulators (no billing-plan change)

Run Auth, Firestore, Storage, and callable Functions locally without deploying
or changing the Firebase plan. Install the Firebase CLI and Java 21. In
PowerShell, start the emulators from the project root:

```powershell
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:start --project mozhimithra --only auth,firestore,functions,storage
```

In another terminal, launch the app with emulator connections explicitly
enabled:

```powershell
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

Use the email-and-password sign-up flow to create a disposable emulator
account. Emulator accounts and data are local and do not change production
Firebase Auth, Firestore, or Storage. The emulator UI is available at
`http://localhost:4000`. Android emulators connect through `10.0.2.2`; Chrome uses `localhost`.
Windows desktop is intentionally rejected in emulator mode because its Firebase
Storage plugin cannot connect to the Storage emulator. For a physical device,
pass a reachable
development-machine address with
`--dart-define=FIREBASE_EMULATOR_HOST=192.168.1.10` and allow the emulator ports
through the local firewall.

The local Functions emulator returns clearly identified demo tutor replies
instead of calling an AI provider. Cloud Text-to-Speech is disabled locally;
the app falls back to an installed device voice. This setup tests Firebase
Auth, profile persistence, and callable-function wiring without cloud
deployment, provider credentials, or Firebase billing. It does not test live
AI or cloud speech; Malayalam translation practice is not available from the
demo tutor. Do not pass the emulator flag in production builds.

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
