# Mozhi Mithram

A speaking-focused language-learning app built with Flutter and Firebase.

## Firebase Tutor Backend and Speech

The app calls authenticated Firebase callable functions in `asia-south1`. The
Functions backend in `functions/` proxies tutor requests to an
OpenAI-compatible provider and proxies spoken replies to a self-hosted Piper
TTS service. Provider URL, API key, model, and Piper service credentials are
Firebase Functions secrets; they are never shipped in the app.

### Host Piper

The included [Piper API stack](./tts/piper-api/) uses the open-source
[OHF-Voice/piper1-gpl](https://github.com/OHF-Voice/piper1-gpl) engine, a
token-protected gateway, and Caddy for HTTPS. Host it on a Docker machine with a
public DNS name pointing to that machine and inbound ports 80 and 443 open.
First startup downloads the configured voice models (several hundred MB); allow
time and disk space for that download.

1. Copy `tts/piper-api/.env.example` to `.env` in that directory. Set
   `PIPER_TTS_DOMAIN` to the public DNS name and replace
   `PIPER_API_TOKEN` with a unique, URL-safe random secret of at least 32
   characters. For example, generate a secret in PowerShell:

   ```powershell
   $bytes = New-Object byte[] 32
   [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
   [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
   ```

   Keep `.env` private and out of version control. The gateway is the only
   public synthesis endpoint; do not publish or expose Piper's port 5000.
2. From `tts/piper-api/`, start the stack:

   ```powershell
   docker compose up --build -d
   ```

   Caddy obtains and renews a TLS certificate automatically. Check
   `https://your-domain/healthz`; it should return `{"status":"ok"}`. Configure
   `PIPER_VOICES` in `.env` to select the models you have reviewed and are
   authorized to use. The voice list includes Arabic, German, English, French,
   Hindi, Malayalam, Mandarin Chinese, Spanish, and Telugu. **The voice models
   have separate licenses from the Piper engine.** Review each selected model's
   `MODEL_CARD` and original dataset license for your intended commercial use
   before enabling it. Some model cards specify a license, while others refer
   to an external dataset or state that the license is unknown. The app falls
   back to a matching device voice when Piper has no configured model for a
   selected language; it never substitutes a different language.

### Configure Firebase

Enable the **Cloud Functions** API and ensure the Firebase project is on a plan
that supports deployed Functions. Do not put credentials in the app or source
repository. From the project root, configure secrets using the Firebase CLI:

   ```powershell
   firebase use mozhimithra
   firebase functions:secrets:set PIPER_TTS_URL
   firebase functions:secrets:set PIPER_TTS_TOKEN
   firebase functions:secrets:set TUTOR_PROVIDER_URL
   firebase functions:secrets:set TUTOR_API_KEY
   firebase functions:secrets:set TUTOR_MODEL
   ```

   Set `PIPER_TTS_URL` to the Piper HTTPS base URL (for example,
   `https://tts.example.com`, without `/synthesize`) and `PIPER_TTS_TOKEN` to
   the same secret used for `PIPER_API_TOKEN` on the host. The Firebase CLI
   prompts for the values. Never paste secrets into chat or commit them.

   One supported option is the
   [Gemini OpenAI-compatible API](https://ai.google.dev/gemini-api/docs/openai):

   - `TUTOR_PROVIDER_URL`: `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`
   - `TUTOR_API_KEY`: your own Gemini API key, created in [Google AI Studio](https://aistudio.google.com/apikey)
   - `TUTOR_MODEL`: a currently available Gemini model compatible with the endpoint (the official example currently uses `gemini-3.8-flash`)

   Other HTTPS providers with an OpenAI-compatible chat-completions API can
   use the same backend. Deploy only after the Piper host is reachable and the
   secret values are set:

   ```powershell
   firebase deploy --only functions
   ```

Firebase Auth credentials are attached automatically to callable requests.
Functions reject unauthenticated callers and enforce per-user request limits.
Tutor requests include the selected languages, skill level, teaching mode, and
recent conversation turns. No `--dart-define` or separate tutor URL is needed.

Piper audio is returned as WAV through the authenticated Firebase callable.
If the service is unreachable, the selected language has no configured Piper
voice, or a device is offline, the app attempts a matching installed device
voice. Some regional voices may not be available in either engine on every
device. The client does not silently substitute a different language.

The host's compute, storage, and network usage may incur charges with its
provider. Firebase Functions usage may also incur charges under the Firebase
project's billing plan. Functions limit each signed-in user to 12 tutor
requests and 30 speech synthesis requests per minute.

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
Speech recognition remains device-provided; Piper TTS provides tutor replies
and pronunciation examples.

The Voice Trainer's percentage is a match between the intended phrase and the
speech-recognition transcript. It is not an acoustic pronunciation or accent
score.

## Local Firebase emulators (no billing-plan change)

Run Auth, Firestore, Storage, and callable Functions locally without deploying
or changing the Firebase plan. Install the Firebase CLI and Java 21. In
PowerShell, start the emulators from the project root:

```powershell
if (-not (Test-Path .\functions\.secret.local)) {
  @'
TUTOR_PROVIDER_URL=https://example.invalid/v1/chat/completions
TUTOR_API_KEY=emulator-only
TUTOR_MODEL=demo
PIPER_TTS_URL=https://tts.example.invalid
PIPER_TTS_TOKEN=emulator-only
'@ | Set-Content -Encoding Ascii .\functions\.secret.local
}
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:start --project mozhimithra --only auth,firestore,functions,storage
```

The ignored `functions/.secret.local` values above are placeholders for the
demo emulator only; they do not enable AI or affect production secrets.

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
instead of calling an AI provider. Piper cloud speech is disabled locally; the
app falls back to an installed device voice. This setup tests Firebase
Auth, profile persistence, and callable-function wiring without cloud
deployment, provider credentials, or Firebase billing. It does not test live
AI or cloud speech. Do not pass the emulator flag in production builds.

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
