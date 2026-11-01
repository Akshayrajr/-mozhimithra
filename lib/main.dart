import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'ai/recommendation_sheet.dart';
import 'ai/tutor_conversation_sheet.dart';
import 'ai/firebase_tutor_service.dart';
import 'ai/voice_trainer.dart';
import 'ai/tutor_service.dart';
import 'auth/auth_gate.dart';
import 'auth/profile_page.dart';
import 'data/learning_profile.dart';
import 'data/vocabulary.dart';
import 'firebase_options.dart';
import 'firebase_emulators.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (useFirebaseEmulators) {
    await configureFirebaseEmulators();
  }
  runApp(const MozhiMithraApp());
}

class MozhiMithraApp extends StatelessWidget {
  const MozhiMithraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mozhi Mithram',
      locale: const Locale('en'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF23745B),
          surface: const Color(0xFFF7F6F1),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F6F1),
        useMaterial3: true,
      ),
      home: AuthGate(
        homeBuilder: (profile, profiles) =>
            LearningHome(profile: profile, profiles: profiles),
      ),
    );
  }
}

class LearningHome extends StatefulWidget {
  const LearningHome({
    super.key,
    required this.profile,
    this.profiles,
    this.tutorService,
  });

  final LearningProfile profile;
  final LearningProfileRepository? profiles;
  final TutorService? tutorService;

  @override
  State<LearningHome> createState() => _LearningHomeState();
}

class _Challenge {
  const _Challenge({required this.title, required this.goal});

  final String title;
  final String goal;
}

const _challengePath = [
  _Challenge(
    title: 'Speak with confidence',
    goal: 'Greet someone naturally and keep the conversation going.',
  ),
  _Challenge(
    title: 'Sound natural',
    goal: 'Introduce yourself with natural rhythm and follow-up questions.',
  ),
  _Challenge(
    title: 'Use natural expressions',
    goal: 'Make a polite request and respond naturally to the answer.',
  ),
  _Challenge(
    title: 'Handle a real conversation',
    goal: 'Order at a cafe and improvise a follow-up conversation.',
  ),
];

class _LearningHomeState extends State<LearningHome> {
  void _openVoiceTrainer() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F6F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) =>
          VoiceTrainerSheet(profile: _profile, service: _tutorService),
    );
  }

  int _selectedTab = 0;
  late LearningProfile _profile;
  late TutorService _tutorService;
  LearningProgressSummary _progress = const LearningProgressSummary();
  bool _progressLoading = false;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _tutorService = widget.tutorService ?? FirebaseTutorService();
    if (widget.profiles != null) {
      _progressLoading = true;
      _refreshProgress();
      _refreshProfilePhoto();
    }
  }

  _Challenge get _nextChallenge {
    final completed = _progress.completedChallenges;
    final base = _challengePath[completed % _challengePath.length];
    final stage = completed ~/ _challengePath.length + 1;
    return _Challenge(
      title: stage == 1 ? base.title : '${base.title} · Stage $stage',
      goal: stage == 1
          ? base.goal
          : '${base.goal} Make it more detailed than the previous stage.',
    );
  }

  Future<void> _refreshProgress() async {
    final repository = widget.profiles;
    if (repository == null) return;
    try {
      final progress = await repository.loadProgressSummary(_profile);
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _progressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _progressLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load your learning progress.")),
      );
    }
  }

  LearningProfile _copyProfile({
    String? targetLanguage,
    int? dailyGoalMinutes,
    String? skillLevel,
    String? tutorLanguage,
  }) {
    return LearningProfile(
      uid: _profile.uid,
      displayName: _profile.displayName,
      targetLanguage: targetLanguage ?? _profile.targetLanguage,
      dailyGoalMinutes: dailyGoalMinutes ?? _profile.dailyGoalMinutes,
      skillLevel: skillLevel ?? _profile.skillLevel,
      tutorLanguage: tutorLanguage ?? _profile.tutorLanguage,
      profilePhotoPath: _profile.profilePhotoPath,
    );
  }

  Future<void> _refreshProfilePhoto() async {
    final repository = widget.profiles;
    if (repository == null) return;
    try {
      final photoUrl = await repository.profilePhotoUrl(_profile);
      if (mounted) setState(() => _profilePhotoUrl = photoUrl);
    } catch (error, stackTrace) {
      debugPrint('Profile photo could not be loaded: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _openProfile() async {
    final repository = widget.profiles;
    if (repository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile editing is unavailable right now.'),
        ),
      );
      return;
    }

    final previousProfile = _profile;
    final updatedProfile = await Navigator.of(context).push<LearningProfile>(
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          profile: previousProfile,
          photoUrl: _profilePhotoUrl,
          onSave:
              ({
                required displayName,
                required targetLanguage,
                required tutorLanguage,
                required dailyGoalMinutes,
                required skillLevel,
                photo,
                required removePhoto,
              }) => repository.updateProfile(
                previousProfile,
                displayName: displayName,
                targetLanguage: targetLanguage,
                tutorLanguage: tutorLanguage,
                dailyGoalMinutes: dailyGoalMinutes,
                skillLevel: skillLevel,
                photo: photo,
                removePhoto: removePhoto,
              ),
        ),
      ),
    );
    if (updatedProfile == null || !mounted) return;
    setState(() => _profile = updatedProfile);
    await _refreshProfilePhoto();
    if (updatedProfile.targetLanguage != previousProfile.targetLanguage) {
      await _refreshProgress();
    }
  }

  Future<void> _updatePreferences({
    String? targetLanguage,
    int? dailyGoalMinutes,
    String? tutorLanguage,
  }) async {
    final previous = _profile;
    final next = _copyProfile(
      targetLanguage: targetLanguage,
      dailyGoalMinutes: dailyGoalMinutes,
      tutorLanguage: tutorLanguage,
    );
    setState(() => _profile = next);
    final repository = widget.profiles;
    if (repository == null) return;

    try {
      final saved = await repository.updatePreferences(
        previous,
        targetLanguage: targetLanguage,
        dailyGoalMinutes: dailyGoalMinutes,
        tutorLanguage: tutorLanguage,
      );
      if (mounted) setState(() => _profile = saved);
      if (targetLanguage != null) await _refreshProgress();
    } catch (_) {
      if (!mounted) return;
      setState(() => _profile = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save your learning settings.")),
      );
    }
  }

  Future<void> _openGuidedLesson({String? challenge}) {
    return _openTutor(
      mode: TutorMode.guidedLesson,
      scenario: challenge ?? _nextChallenge.goal,
      startInVoiceMode: true,
    );
  }

  Future<void> _openTutor({
    TutorMode mode = TutorMode.conversation,
    String? scenario,
    bool startInVoiceMode = false,
  }) async {
    final continueToNextChallenge = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F6F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => TutorConversationSheet(
        profile: _profile,
        service: _tutorService,
        mode: mode,
        scenario: scenario,
        startInVoiceMode: startInVoiceMode,
        onLessonCompleted: mode == TutorMode.guidedLesson
            ? _recordGuidedLessonCompletion
            : null,
      ),
    );
    if (continueToNextChallenge == true && mounted) {
      await _openGuidedLesson();
    }
  }

  Future<List<String>> _recentActivity() async {
    final repository = widget.profiles;
    if (repository == null) return const [];
    return repository.recentActivitySummary(_profile);
  }

  Future<void> _openPersonalRecommendation() async {
    final startLesson = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F6F1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => RecommendationSheet(
        profile: _profile,
        service: _tutorService,
        loadRecentActivity: _recentActivity,
      ),
    );
    if (startLesson == true && mounted) await _openGuidedLesson();
  }

  Future<void> _recordGuidedLessonCompletion() async {
    final repository = widget.profiles;
    if (repository == null) return;
    await repository.recordTutorLessonCompletion(_profile);
    await _refreshProgress();
  }

  Future<void> _chooseDailyGoal() async {
    final choices = [10, 15, 20, 30];
    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFFF7F6F1),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Daily learning goal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            for (final minutes in choices)
              ListTile(
                title: Text('$minutes minutes'),
                trailing: minutes == _profile.dailyGoalMinutes
                    ? const Icon(Icons.check_rounded, color: Color(0xFF23745B))
                    : null,
                onTap: () => Navigator.pop(context, minutes),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await _updatePreferences(dailyGoalMinutes: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedTab,
          children: [
            _LearnTab(
              profile: _profile,
              profilePhotoUrl: _profilePhotoUrl,
              onProfileTap: _openProfile,
              progress: _progress,
              challenge: _nextChallenge,
              progressLoading: _progressLoading,
              onLanguageChanged: (value) =>
                  _updatePreferences(targetLanguage: value),
              onTutorLanguageChanged: (value) =>
                  _updatePreferences(tutorLanguage: value),
              onChangeDailyGoal: _chooseDailyGoal,
              onStartLesson: (goal) => _openGuidedLesson(challenge: goal),
              onRolePlay: () => _openTutor(
                mode: TutorMode.rolePlay,
                scenario: 'meeting someone and having a natural conversation',
                startInVoiceMode: true,
              ),
              onGetRecommendation: _openPersonalRecommendation,
              onVoiceTrainer: _openVoiceTrainer,
            ),
            _PracticeTab(
              profile: _profile,
              profilePhotoUrl: _profilePhotoUrl,
              onProfileTap: _openProfile,
              streakDays: _progress.currentStreakDays,
              onVoiceConversation: () => _openGuidedLesson(),
              onRolePlay: () => _openTutor(
                mode: TutorMode.rolePlay,
                scenario: 'ordering a drink at a cafe',
                startInVoiceMode: true,
              ),
              onVoiceTrainer: _openVoiceTrainer,
            ),
            _ProgressTab(
              profile: _profile,
              profilePhotoUrl: _profilePhotoUrl,
              onProfileTap: _openProfile,
              progress: _progress,
              challenge: _nextChallenge,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF0E5),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.mic_none_rounded),
            selectedIcon: Icon(Icons.mic_rounded),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Progress',
          ),
        ],
      ),
    );
  }
}

class _LearnTab extends StatelessWidget {
  const _LearnTab({
    required this.profile,
    required this.profilePhotoUrl,
    required this.onProfileTap,
    required this.progress,
    required this.challenge,
    required this.progressLoading,
    required this.onLanguageChanged,
    required this.onTutorLanguageChanged,
    required this.onChangeDailyGoal,
    required this.onStartLesson,
    required this.onRolePlay,
    required this.onGetRecommendation,
    required this.onVoiceTrainer,
  });

  final LearningProfile profile;
  final String? profilePhotoUrl;
  final VoidCallback onProfileTap;
  final LearningProgressSummary progress;
  final _Challenge challenge;
  final bool progressLoading;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onTutorLanguageChanged;
  final VoidCallback onChangeDailyGoal;
  final ValueChanged<String> onStartLesson;
  final VoidCallback onRolePlay;
  final VoidCallback onGetRecommendation;
  final VoidCallback onVoiceTrainer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        _TopBar(
          displayName: profile.displayName,
          photoUrl: profilePhotoUrl,
          onProfileTap: onProfileTap,
          streakDays: progress.currentStreakDays,
        ),
        const SizedBox(height: 28),
        Text(
          '${_timeGreeting()}, ${profile.displayName}',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: const Color(0xFF202A25),
            fontWeight: FontWeight.w800,
            fontSize: 25,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Ready to speak with confidence today?',
          style: TextStyle(color: Color(0xFF737B75), fontSize: 14),
        ),
        const SizedBox(height: 22),
        _LanguagePicker(
          label: 'Learn',
          options: supportedTargetLanguages,
          value: profile.targetLanguage,
          onChanged: onLanguageChanged,
        ),
        const SizedBox(height: 10),
        _LanguagePicker(
          label: 'Explain in',
          options: supportedTutorLanguages,
          value: profile.tutorLanguage,
          onChanged: onTutorLanguageChanged,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: onGetRecommendation,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Recommend my next step'),
          ),
        ),
        const SizedBox(height: 18),
        _LessonCard(
          language: profile.targetLanguage,
          skillLevel: profile.skillLevel,
          challenge: challenge,
          completedChallenges: progress.completedChallenges,
          onStartLesson: () => onStartLesson(challenge.goal),
        ),
        const SizedBox(height: 18),
        _LearningPath(
          completedLessons: progress.completedChallenges,
          onStartLesson: () => onStartLesson(challenge.goal),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: Text(
                'Speak today',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF202A25),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              progressLoading
                  ? 'Loading progress'
                  : '${progress.completedToday} lessons today',
              style: const TextStyle(
                color: Color(0xFF23745B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SkillTile(
                icon: Icons.record_voice_over_rounded,
                title: 'Speaking lesson',
                subtitle: 'Talk with your AI tutor',
                color: const Color(0xFFE8F2E9),
                iconColor: const Color(0xFF23745B),
                onTap: () => onStartLesson(challenge.goal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SkillTile(
                icon: Icons.forum_rounded,
                title: 'Role-play',
                subtitle: 'Practice real conversations',
                color: const Color(0xFFE9ECF6),
                iconColor: const Color(0xFF4A5DAA),
                onTap: onRolePlay,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SkillTile(
          icon: Icons.mic_external_on_rounded,
          title: 'Voice Trainer',
          subtitle: 'Practice pronunciation, rhythm, and clear speech',
          color: const Color(0xFFE9ECF6),
          iconColor: const Color(0xFF4A5DAA),
          onTap: onVoiceTrainer,
        ),
        const SizedBox(height: 25),
        _DailyGoal(
          minutes: profile.dailyGoalMinutes,
          onChanged: onChangeDailyGoal,
        ),
      ],
    );
  }

  /// Returns a greeting appropriate for the current time of day.
  String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    this.displayName = 'Learner',
    this.photoUrl,
    this.onProfileTap,
    this.streakDays = 0,
  });

  final String displayName;
  final String? photoUrl;
  final VoidCallback? onProfileTap;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 340;
        return Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF23745B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Mozhi Mithram',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF202A25),
                  fontSize: compact ? 18 : 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFE58B32),
                      size: 17,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$streakDays',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Account',
              onSelected: (action) async {
                if (action == 'profile') {
                  onProfileTap?.call();
                  return;
                }
                try {
                  await GoogleSignIn.instance.initialize();
                  await GoogleSignIn.instance.signOut();
                } catch (error, stackTrace) {
                  debugPrint('Google sign-out cleanup failed: $error');
                  debugPrintStack(stackTrace: stackTrace);
                }
                await FirebaseAuth.instance.signOut();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded),
                      SizedBox(width: 12),
                      Text('Edit profile'),
                    ],
                  ),
                ),
                PopupMenuItem(value: 'signOut', child: Text('Sign out')),
              ],
              child: CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFFDDEBE4),
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl!),
                child: Text(
                  photoUrl != null
                      ? ''
                      : displayName.isEmpty
                      ? 'L'
                      : displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF23745B),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E2)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Tooltip(
            message: 'Choose language',
            child: Icon(
              Icons.translate_rounded,
              color: Color(0xFF23745B),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFF737B75), fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<String>(
              key: ValueKey(label),
              value: value,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              borderRadius: BorderRadius.circular(12),
              selectedItemBuilder: (context) => [
                for (final language in options)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      language,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              items: [
                for (final language in options)
                  DropdownMenuItem(
                    value: language,
                    child: Text(language, maxLines: 1),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.language,
    required this.skillLevel,
    required this.challenge,
    required this.completedChallenges,
    required this.onStartLesson,
  });

  final String language;
  final String skillLevel;
  final _Challenge challenge;
  final int completedChallenges;
  final VoidCallback onStartLesson;

  String get _greeting => greetingFor(language);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF174F40),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFFFFD08A),
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'SPEAKING COACH · PERSONALIZED PRACTICE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFC8E4D5),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            challenge.goal,
            style: const TextStyle(
              color: Color(0xFFD0E5D9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: Color(0xFFFFD08A),
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${skillLevel[0].toUpperCase()}${skillLevel.substring(1)} · ${challenge.title}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Challenge ${completedChallenges + 1}',
                style: TextStyle(
                  color: Color(0xFFC8E4D5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value:
                  (completedChallenges % _challengePath.length) /
                  _challengePath.length,
              minHeight: 5,
              backgroundColor: Color(0xFF376B5C),
              valueColor: AlwaysStoppedAnimation(Color(0xFFFFCA78)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartLesson,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Continue lesson'),
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF174F40),
                backgroundColor: const Color(0xFFFFD08A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningPath extends StatelessWidget {
  const _LearningPath({
    required this.completedLessons,
    required this.onStartLesson,
  });

  final int completedLessons;
  final VoidCallback onStartLesson;

  @override
  Widget build(BuildContext context) {
    final activeIndex = completedLessons % _challengePath.length;
    final stage = completedLessons ~/ _challengePath.length + 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EBE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your learning path',
                  style: TextStyle(
                    color: Color(0xFF202A25),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'UNIT $stage',
                style: const TextStyle(
                  color: Color(0xFF23745B),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete a tutor lesson to unlock the next step.',
            style: TextStyle(color: Color(0xFF737B75), fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _challengePath.length; index++)
            _PathStep(
              challenge: _challengePath[index],
              index: index,
              activeIndex: activeIndex,
              onTap: index == activeIndex ? onStartLesson : null,
            ),
        ],
      ),
    );
  }
}

class _PathStep extends StatelessWidget {
  const _PathStep({
    required this.challenge,
    required this.index,
    required this.activeIndex,
    required this.onTap,
  });

  final _Challenge challenge;
  final int index;
  final int activeIndex;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final completed = index < activeIndex;
    final active = index == activeIndex;
    final color = completed || active
        ? const Color(0xFF23745B)
        : const Color(0xFFB7C0B9);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 54,
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: completed
                        ? color
                        : active
                        ? const Color(0xFFE8F2E9)
                        : const Color(0xFFF0F2F0),
                    shape: BoxShape.circle,
                    border: active ? Border.all(color: color, width: 2) : null,
                  ),
                  child: Icon(
                    completed
                        ? Icons.check_rounded
                        : active
                        ? Icons.play_arrow_rounded
                        : Icons.lock_rounded,
                    size: 16,
                    color: completed ? Colors.white : color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                challenge.title,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF202A25)
                      : const Color(0xFF737B75),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (active)
              const Text(
                'START',
                style: TextStyle(
                  color: Color(0xFF23745B),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF737B75), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyGoal extends StatelessWidget {
  const _DailyGoal({required this.minutes, required this.onChanged});

  final int minutes;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEFEA),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: Color(0xFF23745B), size: 21),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily goal',
                    style: TextStyle(
                      color: Color(0xFF202A25),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '$minutes minute daily target · tap to change',
                    style: TextStyle(color: Color(0xFF737B75), fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: 31,
              height: 31,
              child: CircularProgressIndicator(
                value: 0,
                strokeWidth: 3,
                backgroundColor: Color(0xFFD3DDD5),
                color: Color(0xFF23745B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeTab extends StatelessWidget {
  const _PracticeTab({
    required this.profile,
    required this.profilePhotoUrl,
    required this.onProfileTap,
    required this.streakDays,
    required this.onVoiceConversation,
    required this.onRolePlay,
    required this.onVoiceTrainer,
  });

  final LearningProfile profile;
  final String? profilePhotoUrl;
  final VoidCallback onProfileTap;
  final int streakDays;
  final VoidCallback onVoiceConversation;
  final VoidCallback onRolePlay;
  final VoidCallback onVoiceTrainer;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        _TopBar(
          displayName: profile.displayName,
          photoUrl: profilePhotoUrl,
          onProfileTap: onProfileTap,
          streakDays: streakDays,
        ),
        const SizedBox(height: 30),
        Text(
          'Practice',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        const Text(
          'Build fluent, natural speech through guided speaking practice.',
          style: TextStyle(color: Color(0xFF737B75), fontSize: 13),
        ),
        const SizedBox(height: 24),
        _PracticeOption(
          icon: Icons.mic_rounded,
          title: 'Guided speaking lesson',
          subtitle: 'Learn phrases, practice aloud, and get corrections',
          color: const Color(0xFFE8F2E9),
          onTap: onVoiceConversation,
        ),
        const SizedBox(height: 12),
        _PracticeOption(
          icon: Icons.record_voice_over_rounded,
          title: 'Natural conversation',
          subtitle: 'Practice speaking spontaneously with your tutor',
          color: const Color(0xFFE8F2E9),
          onTap: onVoiceConversation,
        ),
        const SizedBox(height: 12),
        _PracticeOption(
          icon: Icons.headphones_rounded,
          title: 'Role-play a scene',
          subtitle: 'Practice an everyday conversation with your tutor',
          color: const Color(0xFFE9ECF6),
          onTap: onRolePlay,
        ),
        const SizedBox(height: 12),
        _PracticeOption(
          icon: Icons.mic_external_on_rounded,
          title: 'Voice Trainer',
          subtitle: 'Listen, repeat, and practice clear pronunciation',
          color: const Color(0xFFF0EDFF),
          onTap: onVoiceTrainer,
        ),
      ],
    );
  }
}

class _PracticeOption extends StatelessWidget {
  const _PracticeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF23745B)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF737B75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF929992),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({
    required this.profile,
    required this.profilePhotoUrl,
    required this.onProfileTap,
    required this.progress,
    required this.challenge,
  });

  final LearningProfile profile;
  final String? profilePhotoUrl;
  final VoidCallback onProfileTap;
  final LearningProgressSummary progress;
  final _Challenge challenge;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        _TopBar(
          displayName: profile.displayName,
          photoUrl: profilePhotoUrl,
          onProfileTap: onProfileTap,
          streakDays: progress.currentStreakDays,
        ),
        const SizedBox(height: 30),
        Text(
          'Your progress',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          'Learning ${profile.targetLanguage} · ${profile.skillLevel}',
          style: TextStyle(color: Color(0xFF737B75), fontSize: 13),
        ),
        const SizedBox(height: 23),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF174F40),
            borderRadius: BorderRadius.circular(21),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SPEAKING LESSONS THIS WEEK',
                style: TextStyle(
                  color: Color(0xFFC8E4D5),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${progress.completionsThisWeek}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'spoken lessons completed',
                style: TextStyle(color: Color(0xFFD0E5D9), fontSize: 13),
              ),
              SizedBox(height: 20),
              _WeeklyBars(completions: progress.weeklyCompletions),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ProgressStat(
          icon: Icons.local_fire_department_rounded,
          title: '${progress.currentStreakDays} day streak',
          subtitle: 'Practice each day to keep it going.',
          color: const Color(0xFFFFF0D9),
        ),
        const SizedBox(height: 11),
        _ProgressStat(
          icon: Icons.auto_stories_rounded,
          title: '${progress.completedChallenges} speaking lessons completed',
          subtitle: 'Next: ${challenge.title}',
          color: const Color(0xFFE8F2E9),
        ),
      ],
    );
  }
}

class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.completions});

  final List<int> completions;

  @override
  Widget build(BuildContext context) {
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    final maxCompletions = completions.fold<int>(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    return SizedBox(
      height: 74,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(completions.length, (index) {
          final day = today.subtract(
            Duration(days: completions.length - 1 - index),
          );
          final barHeight = maxCompletions == 0
              ? 3.0
              : 42.0 * completions[index] / maxCompletions;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 22,
                height: barHeight,
                decoration: BoxDecoration(
                  color: index == completions.length - 1
                      ? const Color(0xFFFFD08A)
                      : const Color(0xFF72A78E),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                weekdayLabels[day.weekday - 1],
                style: const TextStyle(color: Color(0xFFC8E4D5), fontSize: 10),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF23745B)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF737B75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
