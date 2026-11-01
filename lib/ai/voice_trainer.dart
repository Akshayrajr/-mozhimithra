import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/learning_profile.dart';
import '../data/vocabulary.dart';
import 'speech_audio_service.dart';
import 'tutor_service.dart';
import 'voice_locale.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Data model for a single training card.
// ─────────────────────────────────────────────────────────────────────────────
class _TrainingCard {
  _TrainingCard({
    required this.phrase,
    required this.pronunciation,
    required this.meaning,
  });

  final String phrase;
  final String pronunciation;
  final String meaning;

  double? score;
  String? spokenText;
  bool get attempted => score != null;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Voice Trainer — full-screen bottom-sheet experience.
// ─────────────────────────────────────────────────────────────────────────────
class VoiceTrainerSheet extends StatefulWidget {
  const VoiceTrainerSheet({
    super.key,
    required this.profile,
    required this.service,
  });

  final LearningProfile profile;
  final TutorService service;

  @override
  State<VoiceTrainerSheet> createState() => _VoiceTrainerSheetState();
}

class _VoiceTrainerSheetState extends State<VoiceTrainerSheet>
    with TickerProviderStateMixin {
  late final SpeechAudioService _speechAudioService;
  // ── Voice engines ────────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _speechInitialized = false;
  bool _speechAvailable = false;

  // ── Training state ───────────────────────────────────────────────────────
  late List<_TrainingCard> _cards;
  int _currentIndex = 0;
  bool _listening = false;
  bool _speaking = false;
  String _heardWords = '';
  String? _voiceError;
  bool _sessionComplete = false;
  bool _showResult = false;

  // ── Animations ───────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late AnimationController _scoreRevealController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scoreRevealAnimation;

  // ── AI feedback ──────────────────────────────────────────────────────────
  String? _aiFeedback;
  bool _loadingFeedback = false;

  @override
  void initState() {
    super.initState();
    _speechAudioService = FirebaseSpeechAudioService();
    _buildDeck();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _scoreRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scoreRevealAnimation = CurvedAnimation(
      parent: _scoreRevealController,
      curve: Curves.elasticOut,
    );
  }

  void _buildDeck() {
    final vocab = vocabularyFor(widget.profile.targetLanguage);
    _cards = vocab
        .map(
          (v) => _TrainingCard(
            phrase: v.phrase,
            pronunciation: v.pronunciation,
            meaning: v.meaning,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scoreRevealController.dispose();
    _stopListening();
    _tts.stop();
    unawaited(_speechAudioService.dispose());
    super.dispose();
  }

  // ── TTS ────────────────────────────────────────────────────────────────────

  Future<void> _speakPhrase(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _speaking = true);
    try {
      await _speechAudioService.speak(
        text: text,
        language: widget.profile.targetLanguage,
      );
      if (mounted) setState(() => _speaking = false);
    } catch (_) {
      try {
        final locale = await setAvailableTtsLanguage(
          _tts,
          widget.profile.targetLanguage,
        );
        if (locale == null) {
          if (!mounted) return;
          setState(() {
            _speaking = false;
            _voiceError =
                'Cloud speech failed and no ${widget.profile.targetLanguage} '
                'device voice is installed. Check Firebase TTS or install '
                'device voice data.';
          });
          return;
        }
        await _tts.setSpeechRate(0.45);
        await _tts.stop();
        _tts.setCompletionHandler(() {
          if (mounted) setState(() => _speaking = false);
        });
        final result = await _tts.speak(text);
        if ((result == false || result == 0) && mounted) {
          setState(() {
            _speaking = false;
            _voiceError = 'Neither cloud nor device speech could play the phrase.';
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _speaking = false;
          _voiceError =
              'Speech playback failed. Check Firebase TTS and device voice settings.';
        });
      }
    }
  }

  // ── STT ────────────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (_listening) return;

    if (!_speechInitialized) {
      try {
        _speechAvailable = await _speech.initialize(
          onError: _handleSpeechError,
          onStatus: _handleSpeechStatus,
          debugLogging: false,
        );
      } catch (_) {
        _speechAvailable = false;
      }
      _speechInitialized = true;
    }
    if (!_speechAvailable) {
      setState(
        () => _voiceError = "Voice input isn't available on this device.",
      );
      return;
    }

    setState(() {
      _listening = true;
      _voiceError = null;
      _heardWords = '';
      _showResult = false;
      _aiFeedback = null;
    });

    try {
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: localeCodeForLanguage(widget.profile.targetLanguage),
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
      );
    } catch (_) {
      _failListening();
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _heardWords = result.recognizedWords);
    if (result.finalResult) {
      _stopListening();
      _evaluatePronunciation(result.recognizedWords);
    }
  }

  void _handleSpeechStatus(String status) {
    if ((status == 'done' || status == 'notListening') &&
        _listening &&
        mounted) {
      setState(() => _listening = false);
      if (_heardWords.isNotEmpty) _evaluatePronunciation(_heardWords);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _voiceError = "Couldn't hear you. Tap the mic and try again.";
    });
  }

  void _failListening() {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _voiceError = "Voice input isn't available on this device.";
    });
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    setState(() => _listening = false);
    try {
      await _speech.stop();
    } catch (_) {}
  }

  // ── Scoring ────────────────────────────────────────────────────────────────

  void _evaluatePronunciation(String spoken) {
    final card = _cards[_currentIndex];
    final expected = card.phrase.toLowerCase().trim();
    final heard = spoken.toLowerCase().trim();

    // Simple word-overlap similarity — works for short phrases.
    final expectedWords = expected.split(RegExp(r'\s+'));
    final heardWords = heard.split(RegExp(r'\s+'));
    int matched = 0;
    for (final word in expectedWords) {
      if (heardWords.contains(word)) matched++;
    }
    // Also give partial credit for close character match.
    final charSim = _charSimilarity(expected, heard);
    final wordSim = expectedWords.isEmpty
        ? 0.0
        : matched / expectedWords.length;
    final score = ((wordSim * 0.6) + (charSim * 0.4)).clamp(0.0, 1.0);

    setState(() {
      card.score = score;
      card.spokenText = spoken;
      _showResult = true;
    });
    _scoreRevealController
      ..reset()
      ..forward();

    // Ask AI for feedback if connected.
    _requestAIFeedback(card, spoken, score);
  }

  double _charSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final maxLen = max(a.length, b.length);
    int common = 0;
    final bChars = b.split('');
    for (final char in a.split('')) {
      final idx = bChars.indexOf(char);
      if (idx != -1) {
        common++;
        bChars.removeAt(idx);
      }
    }
    return common / maxLen;
  }

  Future<void> _requestAIFeedback(
    _TrainingCard card,
    String spoken,
    double score,
  ) async {
    if (!widget.service.isConfigured) return;
    setState(() => _loadingFeedback = true);
    try {
      final feedback = await widget.service.reply(
        profile: widget.profile,
        history: [
          TutorTurn(
            role: 'user',
            content:
                'I tried to say "${card.phrase}" (${card.pronunciation}) '
                'but the speech recognizer heard "$spoken". '
                'The transcript phrase match was ${(score * 100).round()}%. '
                'You only know the recognized text, not the audio. Do not '
                'claim to have heard or measured specific sounds or accent. '
                'Give one brief, encouraging practice tip in '
                '${widget.profile.tutorLanguage}, focusing on a likely '
                'pronunciation or rhythm point and invite me to repeat.',
          ),
        ],
        mode: TutorMode.conversation,
      );
      if (!mounted) return;
      setState(() {
        _aiFeedback = feedback;
        _loadingFeedback = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingFeedback = false);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _nextCard() {
    if (_currentIndex >= _cards.length - 1) {
      setState(() => _sessionComplete = true);
      return;
    }
    setState(() {
      _currentIndex++;
      _showResult = false;
      _heardWords = '';
      _voiceError = null;
      _aiFeedback = null;
    });
  }

  void _retryCard() {
    setState(() {
      _cards[_currentIndex].score = null;
      _cards[_currentIndex].spokenText = null;
      _showResult = false;
      _heardWords = '';
      _voiceError = null;
      _aiFeedback = null;
    });
  }

  void _restartSession() {
    _buildDeck();
    setState(() {
      _currentIndex = 0;
      _showResult = false;
      _heardWords = '';
      _voiceError = null;
      _sessionComplete = false;
      _aiFeedback = null;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _scoreColor(double score) {
    if (score >= 0.8) return const Color(0xFF23745B);
    if (score >= 0.5) return const Color(0xFFE58B32);
    return const Color(0xFFB33B2E);
  }

  String _scoreEmoji(double score) {
    if (score >= 0.8) return '🌟';
    if (score >= 0.5) return '👍';
    return '💪';
  }

  String _scoreLabel(double score) {
    if (score >= 0.8) return 'Strong phrase match';
    if (score >= 0.5) return 'Close phrase match';
    return 'Try the phrase again';
  }

  int get _totalAttempted => _cards.where((c) => c.attempted).length;

  double get _averageScore {
    final attempted = _cards.where((c) => c.attempted);
    if (attempted.isEmpty) return 0;
    return attempted.map((c) => c.score!).reduce((a, b) => a + b) /
        attempted.length;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      child: SizedBox(
        height: screenHeight,
        child: Column(
          children: [
            _buildHeader(context),
            if (!_sessionComplete) _buildProgressBar(),
            Expanded(
              child: _sessionComplete
                  ? _buildSessionSummary()
                  : _buildTrainingCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF23745B), Color(0xFF1A5C46)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.record_voice_over_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Speak & repeat',
                  style: const TextStyle(
                    color: Color(0xFF202A25),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${widget.profile.targetLanguage} · '
                  '$_totalAttempted/$_cards.length practiced',
                  style: const TextStyle(
                    color: Color(0xFF737B75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close trainer',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = _cards.isEmpty ? 0.0 : (_currentIndex + 1) / _cards.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: progress,
          minHeight: 5,
          backgroundColor: const Color(0xFFE4E7E2),
          valueColor: const AlwaysStoppedAnimation(Color(0xFF23745B)),
        ),
      ),
    );
  }

  Widget _buildTrainingCard() {
    final card = _cards[_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Phrase card ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF174F40), Color(0xFF1A5C46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF174F40).withValues(alpha: 0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_currentIndex + 1} / ${_cards.length}',
                        style: const TextStyle(
                          color: Color(0xFFC8E4D5),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Listen to pronunciation',
                      onPressed: _speaking
                          ? null
                          : () => _speakPhrase(card.phrase),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _speaking
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFFD08A),
                                ),
                              )
                            : const Icon(
                                Icons.volume_up_rounded,
                                color: Color(0xFFFFD08A),
                                size: 24,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  card.phrase,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  card.pronunciation,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card.meaning,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Instruction ────────────────────────────────────────────────
          if (!_showResult && !_listening)
            Center(
              child: Text(
                'Tap the speaker to listen, then hold the mic and repeat',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF737B75), fontSize: 13),
              ),
            ),

          // ── Listening indicator ────────────────────────────────────────
          if (_listening)
            Column(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF23745B).withValues(alpha: 0.25),
                          const Color(0xFF23745B).withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Color(0xFF23745B),
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _heardWords.isEmpty ? 'Listening…' : _heardWords,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF23745B),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontStyle: _heardWords.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ],
            ),

          // ── Voice error ────────────────────────────────────────────────
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _voiceError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFB33B2E), fontSize: 12),
              ),
            ),

          // ── Result ─────────────────────────────────────────────────────
          if (_showResult) ...[
            const SizedBox(height: 4),
            ScaleTransition(
              scale: _scoreRevealAnimation,
              child: _buildScoreCard(card),
            ),
          ],

          const SizedBox(height: 20),

          // ── Actions ────────────────────────────────────────────────────
          if (!_showResult)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _listening
                    ? () => _stopListening()
                    : _speaking
                    ? null
                    : _startListening,
                icon: Icon(
                  _listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  size: 22,
                ),
                label: Text(
                  _listening ? 'Stop listening' : 'Start speaking',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _listening
                      ? const Color(0xFFB33B2E)
                      : const Color(0xFF23745B),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          if (_showResult) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retryCard,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    label: const Text('Try again'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _nextCard,
                    icon: Icon(
                      _currentIndex >= _cards.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 19,
                    ),
                    label: Text(
                      _currentIndex >= _cards.length - 1 ? 'Finish' : 'Next',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF23745B),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCard(_TrainingCard card) {
    final score = card.score ?? 0;
    final pct = (score * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _scoreColor(score).withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _scoreColor(score).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_scoreEmoji(score), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Text(
                '$pct%',
                style: TextStyle(
                  color: _scoreColor(score),
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _scoreLabel(score),
            style: TextStyle(
              color: _scoreColor(score),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Speech-recognition match, not an accent score',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF737B75), fontSize: 11),
          ),
          if (card.spokenText != null && card.spokenText!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Speech recognition heard:',
                    style: TextStyle(
                      color: Color(0xFF737B75),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.spokenText!,
                    style: const TextStyle(
                      color: Color(0xFF202A25),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // ── AI pronunciation feedback ──────────────────────────────────
          if (_loadingFeedback)
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF23745B),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Getting pronunciation tip…',
                    style: TextStyle(
                      color: Color(0xFF737B75),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          if (_aiFeedback != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF23745B),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiFeedback!,
                      style: const TextStyle(
                        color: Color(0xFF202A25),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Session summary ────────────────────────────────────────────────────────

  Widget _buildSessionSummary() {
    final avgPct = (_averageScore * 100).round();
    final attempted = _totalAttempted;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF174F40), Color(0xFF1A5C46)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 10),
                const Text(
                  'Session Complete!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You practiced $attempted phrase${attempted == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _scoreEmoji(_averageScore),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average phrase match: $avgPct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            _scoreLabel(_averageScore),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Per-card results ────────────────────────────────────────────
          Text(
            'Results',
            style: const TextStyle(
              color: Color(0xFF202A25),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._cards.map(_buildSummaryRow),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _restartSession,
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Practice again'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF23745B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(_TrainingCard card) {
    final score = card.score ?? 0;
    final pct = (score * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _scoreColor(score).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '$pct%',
              style: TextStyle(
                color: _scoreColor(score),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.phrase,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                Text(
                  card.meaning,
                  style: const TextStyle(
                    color: Color(0xFF737B75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(_scoreEmoji(score), style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}
