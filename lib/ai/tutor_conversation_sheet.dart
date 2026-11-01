import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../data/learning_profile.dart';
import 'speech_audio_service.dart';
import 'tutor_service.dart';
import 'voice_locale.dart';

class TutorConversationSheet extends StatefulWidget {
  const TutorConversationSheet({
    super.key,
    required this.profile,
    required this.service,
    this.mode = TutorMode.conversation,
    this.scenario,
    this.startInVoiceMode = false,
    this.onLessonCompleted,
    this.speechAudioService,
  });

  final LearningProfile profile;
  final TutorService service;
  final TutorMode mode;
  final String? scenario;
  final bool startInVoiceMode;
  final Future<void> Function()? onLessonCompleted;
  final SpeechAudioService? speechAudioService;

  @override
  State<TutorConversationSheet> createState() => _TutorConversationSheetState();
}

class _TutorConversationSheetState extends State<TutorConversationSheet> {
  late final SpeechAudioService _speechAudioService;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  late final List<TutorTurn> _history;
  bool _sending = false;
  bool _lessonComplete = false;
  bool _progressSaveFailed = false;
  String? _error;

  // Voice input / output state.
  bool _speechInitialized = false;
  bool _speechAvailable = false;
  bool _listening = false;
  bool _voiceConversation = false;
  bool _autoSpeak = false;
  String _heardWords = '';
  String? _voiceError;

  @override
  void initState() {
    super.initState();
    _speechAudioService =
        widget.speechAudioService ?? FirebaseSpeechAudioService();
    final scenario = widget.scenario;
    _history = [
      TutorTurn(
        role: 'assistant',
        content: _initialTutorMessage(widget.profile, widget.mode, scenario),
      ),
    ];
    if (widget.startInVoiceMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startVoiceConversation();
      });
    }
  }

  String _initialTutorMessage(
    LearningProfile profile,
    TutorMode mode,
    String? scenario,
  ) {
    if (profile.tutorLanguage == 'Malayalam') {
      if (mode == TutorMode.guidedLesson) {
        if (scenario != null) {
          return 'ഹായ് ${profile.displayName}. ഇന്നത്തെ challenge: $scenario. നമുക്ക് ഇത് ഘട്ടംഘട്ടമായി പരിശീലിക്കാം.';
        }
        return 'ഹായ് ${profile.displayName}. ${profile.targetLanguage}യിൽ ഒരു ചെറിയ പാഠം ഘട്ടംഘട്ടമായി പഠിക്കാം. ആദ്യ പ്രവർത്തനത്തോടെ തുടങ്ങാം.';
      }
      return scenario == null
          ? 'ഹായ് ${profile.displayName}. ${profile.targetLanguage}യിൽ സ്വാഭാവികമായി സംസാരിക്കാൻ പരിശീലിക്കാം. ഒരു അഭിവാദ്യം ശബ്ദമായി പറയൂ.'
          : '${profile.targetLanguage}യിൽ $scenario പരിശീലിക്കാം. മൈക്ക് അമർത്തി ആദ്യ മറുപടി ശബ്ദമായി പറയൂ.';
    }
    if (mode == TutorMode.guidedLesson) {
      if (scenario != null) {
        return 'Hi ${profile.displayName}. Today’s challenge: $scenario. Let’s work through it step by step.';
      }
      return 'Hi ${profile.displayName}. Let’s take a short ${profile.targetLanguage} lesson step by step. We’ll set one goal, practice, and adjust as we go.';
    }
    return scenario == null
        ? 'Hi ${profile.displayName}. Let’s practice speaking ${profile.targetLanguage} naturally. Start by saying a greeting aloud.'
        : 'Let’s role-play $scenario in ${profile.targetLanguage}. Tap the mic and say your first line aloud.';
  }

  @override
  void dispose() {
    _stopListening();
    _tts.stop();
    unawaited(_speechAudioService.dispose());
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage({
    String? retryText,
    String? recognizedSpeech,
  }) async {
    final text = (recognizedSpeech ?? retryText ?? _inputController.text)
        .trim();
    if (text.isEmpty || _sending || !widget.service.isConfigured) return;
    if (_listening) await _stopListening();

    if (retryText == null || recognizedSpeech != null) {
      _inputController.clear();
      _history.add(TutorTurn(role: 'user', content: text));
    }
    setState(() {
      _sending = true;
      _error = null;
      _voiceError = null;
    });
    _scrollToBottom();

    try {
      final response = await widget.service.reply(
        profile: widget.profile,
        history: List.unmodifiable(_history),
        mode: widget.mode,
      );
      if (!mounted) return;
      final learnerTurnCount = _history
          .where((turn) => turn.role == 'user')
          .length;
      final lessonCompleted =
          widget.mode == TutorMode.guidedLesson &&
          !_lessonComplete &&
          learnerTurnCount >= 3;
      setState(() {
        _history.add(TutorTurn(role: 'assistant', content: response));
        _sending = false;
        if (lessonCompleted) {
          _lessonComplete = true;
          _voiceConversation = false;
        }
      });
      if (lessonCompleted) {
        try {
          await widget.onLessonCompleted?.call();
        } catch (_) {
          if (mounted) {
            setState(() {
              _progressSaveFailed = true;
              _error = "Lesson completed, but progress couldn't be saved.";
            });
          }
        }
      }
      if (_voiceConversation || _autoSpeak) await _speak(response);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is TutorServiceException
            ? error.message
            : 'Could not reach your tutor. Check your connection and try again.';
        _sending = false;
        _voiceConversation = false;
      });
    }
    _scrollToBottom();
  }

  // ── Voice helpers ───────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_listening) {
      await _stopListening();
      return;
    }
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_listening) return;
    if (!widget.service.isConfigured) return;

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
      setState(() {
        _voiceConversation = false;
        _voiceError = "Voice input isn't available on this device.";
      });
      return;
    }

    setState(() {
      _listening = true;
      _voiceError = null;
      _heardWords = _inputController.text;
    });
    try {
      await _speech.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          localeId: localeCodeForLanguage(widget.profile.targetLanguage),
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 4),
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
    setState(() {
      _heardWords = result.recognizedWords;
      _inputController.text = result.recognizedWords;
      _inputController.selection = TextSelection.collapsed(
        offset: result.recognizedWords.length,
      );
    });
    if (result.finalResult) _finishRecognizedTurn(result.recognizedWords);
  }

  void _handleSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_listening && mounted) {
        final words = _heardWords;
        if (_voiceConversation && words.trim().isNotEmpty) {
          _finishRecognizedTurn(words);
        } else {
          setState(() => _listening = false);
        }
      }
    }
  }

  Future<void> _finishRecognizedTurn(String words) async {
    if (!_listening || !mounted) return;
    setState(() {
      _listening = false;
      _voiceError = null;
    });
    try {
      await _speech.stop();
    } catch (_) {
      // The recognition service may already have stopped after a final result.
    }

    if (!mounted) return;
    if (_voiceConversation && words.trim().isNotEmpty) {
      await _sendMessage(recognizedSpeech: words);
    } else if (words.trim().isEmpty && _voiceConversation) {
      setState(() {
        _voiceError = "I didn't catch that. Please try speaking again.";
      });
      await _startListening();
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _voiceConversation = false;
      _voiceError = "Couldn't hear you. Try again or type your answer.";
    });
  }

  void _failListening() {
    if (!mounted) return;
    setState(() {
      _listening = false;
      _voiceConversation = false;
      _voiceError = "Voice input isn't available on this device.";
    });
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    if (mounted) {
      setState(() => _listening = false);
    } else {
      _listening = false;
    }
    try {
      await _speech.stop();
    } catch (_) {
      // Stopping an already-stopped session is harmless.
    }
  }

  Future<void> _speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    try {
      await _speechAudioService.speak(
        text: trimmed,
        language: widget.profile.tutorLanguage,
      );
      if (_voiceConversation && mounted) await _startListening();
      return;
    } catch (_) {
      try {
        final locale = await setAvailableTtsLanguage(
          _tts,
          widget.profile.tutorLanguage,
        );
        if (locale == null) {
          if (mounted) {
            setState(() {
              _voiceError =
                  'Cloud speech failed and no ${widget.profile.tutorLanguage} '
                  'device voice is installed. Install its voice data or check '
                  'Firebase Text-to-Speech setup.';
            });
          }
          return;
        }
        await _tts.setSpeechRate(0.5);
        await _tts.stop();
        await _tts.awaitSpeakCompletion(true);
        final result = await _tts.speak(trimmed);
        if ((result == false || result == 0) && mounted) {
          setState(() {
            _voiceError =
                'Neither cloud nor device speech could play the reply.';
          });
          return;
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _voiceError =
              'Spoken replies failed. Check Firebase TTS and device voice settings.';
        });
        if (_voiceConversation) await _startListening();
        return;
      }
      if (_voiceConversation && mounted) await _startListening();
    }
  }

  Future<void> _startVoiceConversation() async {
    if (_voiceConversation || !widget.service.isConfigured) return;
    setState(() {
      _voiceConversation = true;
      _autoSpeak = true;
      _voiceError = null;
    });
    final lastTurn = _history.last;
    if (lastTurn.role == 'assistant') {
      await _speak(lastTurn.content);
    } else {
      await _startListening();
    }
  }

  Future<void> _toggleVoiceConversation() async {
    if (_voiceConversation) {
      setState(() {
        _voiceConversation = false;
        _listening = false;
        _voiceError = null;
      });
      try {
        await _speech.stop();
        await _tts.stop();
        await _speechAudioService.stop();
      } catch (_) {
        // The voice engines may already be idle.
      }
      return;
    }
    await _startVoiceConversation();
  }

  Future<void> _toggleAutoSpeak() async {
    final enabled = !_autoSpeak;
    setState(() => _autoSpeak = enabled);
    if (!enabled) {
      try {
        await _tts.stop();
      } catch (_) {
        // Ignore stop failures when muting.
      }
      return;
    }
    if (_history.isNotEmpty && _history.last.role == 'assistant') {
      await _speak(_history.last.content);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height * 0.84;
    return SafeArea(
      child: SizedBox(
        height: availableHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF23745B),
                    size: 21,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (widget.mode) {
                            TutorMode.guidedLesson =>
                              'Guided ${widget.profile.targetLanguage} lesson',
                            TutorMode.rolePlay =>
                              'Role-play · ${widget.profile.targetLanguage}',
                            TutorMode.conversation =>
                              'Your ${widget.profile.targetLanguage} tutor',
                            TutorMode.translationPractice =>
                              'Malayalam to ${widget.profile.targetLanguage}',
                          },
                          style: const TextStyle(
                            color: Color(0xFF202A25),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${widget.profile.skillLevel} · replies adapt to your level',
                          style: const TextStyle(
                            color: Color(0xFF737B75),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _voiceConversation
                        ? 'Stop voice conversation'
                        : 'Start voice conversation',
                    onPressed: widget.service.isConfigured
                        ? _toggleVoiceConversation
                        : null,
                    icon: Icon(
                      _voiceConversation
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                      color: _voiceConversation
                          ? const Color(0xFFB33B2E)
                          : const Color(0xFF23745B),
                    ),
                  ),
                  IconButton(
                    tooltip: _autoSpeak
                        ? 'Turn off voice replies'
                        : 'Speak tutor replies aloud',
                    onPressed: _voiceConversation ? null : _toggleAutoSpeak,
                    icon: Icon(
                      _autoSpeak
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      color: _autoSpeak
                          ? const Color(0xFF23745B)
                          : const Color(0xFF737B75),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close tutor',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            if (!widget.service.isConfigured)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0D9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Firebase tutor functions are not available. Deploy the '
                  'Firebase Functions and configure the provider secrets.',
                  style: TextStyle(color: Color(0xFF76521E), fontSize: 12),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _history.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _history.length) {
                    return const _TutorBubble(
                      content: 'Thinking…',
                      isTutor: true,
                      muted: true,
                    );
                  }
                  final turn = _history[index];
                  final isTutor = turn.role == 'assistant';
                  return _TutorBubble(
                    content: turn.content,
                    isTutor: isTutor,
                    onPlay: isTutor ? () => _speak(turn.content) : null,
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB33B2E),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (_history.isNotEmpty && _history.last.role == 'user')
                      TextButton.icon(
                        onPressed: () =>
                            _sendMessage(retryText: _history.last.content),
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            if (_listening || _voiceError != null || _voiceConversation)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: _listening
                    ? Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF23745B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _heardWords.isEmpty
                                  ? 'Listening\u2026'
                                  : _heardWords,
                              style: const TextStyle(
                                color: Color(0xFF23745B),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        _voiceError ??
                            (_sending
                                ? 'Waiting for your tutor...'
                                : 'Voice conversation is on. Speak when you’re ready.'),
                        style: TextStyle(
                          color: _voiceError == null
                              ? const Color(0xFF23745B)
                              : const Color(0xFFB33B2E),
                          fontSize: 12,
                        ),
                      ),
              ),
            if (_lessonComplete)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _progressSaveFailed
                            ? 'Practice complete, but progress could not be saved.'
                            : 'Practice complete! Your next lesson is ready.',
                        style: TextStyle(
                          color: _progressSaveFailed
                              ? const Color(0xFFB33B2E)
                              : const Color(0xFF23745B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(context, !_progressSaveFailed),
                      child: Text(
                        _progressSaveFailed ? 'Close' : 'Next challenge',
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sendButton = IconButton.filled(
                    tooltip: 'Send message',
                    onPressed:
                        widget.service.isConfigured &&
                            !_sending &&
                            !_lessonComplete
                        ? _sendMessage
                        : null,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF23745B),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(48, 48),
                    ),
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded),
                  );
                  final micButton = IconButton(
                    tooltip: _voiceConversation
                        ? 'Stop voice conversation'
                        : _listening
                        ? 'Stop listening'
                        : 'Speak your answer',
                    onPressed:
                        widget.service.isConfigured &&
                            !_sending &&
                            !_lessonComplete
                        ? _voiceConversation
                              ? _toggleVoiceConversation
                              : _toggleListening
                        : null,
                    icon: Icon(
                      _voiceConversation
                          ? Icons.stop_circle_rounded
                          : _listening
                          ? Icons.stop_circle_rounded
                          : Icons.mic_rounded,
                      color: _voiceConversation || _listening
                          ? const Color(0xFFB33B2E)
                          : const Color(0xFF23745B),
                    ),
                  );
                  final input = TextField(
                    controller: _inputController,
                    enabled:
                        widget.service.isConfigured &&
                        !_sending &&
                        !_lessonComplete,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText:
                          'Type in ${widget.profile.targetLanguage} if needed',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE4E7E2)),
                      ),
                    ),
                  );

                  if (constraints.maxWidth < 360) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        input,
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [micButton, sendButton],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 4),
                      micButton,
                      const SizedBox(width: 4),
                      sendButton,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorBubble extends StatelessWidget {
  const _TutorBubble({
    required this.content,
    required this.isTutor,
    this.muted = false,
    this.onPlay,
  });

  final String content;
  final bool isTutor;
  final bool muted;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final color = isTutor ? Colors.white : const Color(0xFF174F40);
    return Align(
      alignment: isTutor ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  content,
                  style: TextStyle(
                    color: isTutor ? const Color(0xFF202A25) : Colors.white,
                    height: 1.4,
                    fontStyle: muted ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
              ),
              if (onPlay != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6, top: 1),
                  child: InkWell(
                    onTap: onPlay,
                    borderRadius: BorderRadius.circular(18),
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFF23745B),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
