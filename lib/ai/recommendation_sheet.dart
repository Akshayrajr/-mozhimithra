import 'package:flutter/material.dart';

import '../data/learning_profile.dart';
import 'tutor_service.dart';

class RecommendationSheet extends StatefulWidget {
  const RecommendationSheet({
    super.key,
    required this.profile,
    required this.service,
    required this.loadRecentActivity,
  });

  final LearningProfile profile;
  final TutorService service;
  final Future<List<String>> Function() loadRecentActivity;

  @override
  State<RecommendationSheet> createState() => _RecommendationSheetState();
}

class _RecommendationSheetState extends State<RecommendationSheet> {
  String? _recommendation;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.service.isConfigured) _loadRecommendation();
  }

  Future<void> _loadRecommendation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await widget.loadRecentActivity();
      final recommendation = await widget.service.recommendNextActivity(
        profile: widget.profile,
        recentActivity: activity,
      );
      if (!mounted) return;
      setState(() {
        _recommendation = recommendation;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is TutorServiceException
            ? error.message
            : 'Could not build a recommendation. Check your connection and retry.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFF23745B),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Your next learning step',
                      style: TextStyle(
                        color: Color(0xFF202A25),
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close recommendation',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: !_isConfigured
                      ? const Text(
                          'Connect your tutor backend to get a recommendation based on your learning profile and recent practice.',
                          style: TextStyle(
                            color: Color(0xFF737B75),
                            height: 1.5,
                          ),
                        )
                      : _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF23745B),
                            ),
                          ),
                        )
                      : _error != null
                      ? Text(
                          _error!,
                          style: const TextStyle(
                            color: Color(0xFFB33B2E),
                            height: 1.5,
                          ),
                        )
                      : Text(
                          _recommendation ?? '',
                          style: const TextStyle(
                            color: Color(0xFF303A34),
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                ),
              ),
              if (widget.service.isConfigured && !_loading)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _error != null
                      ? OutlinedButton.icon(
                          onPressed: _loadRecommendation,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry recommendation'),
                        )
                      : _recommendation == null
                      ? null
                      : FilledButton.icon(
                          onPressed: () => Navigator.pop(context, true),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start guided lesson'),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isConfigured => widget.service.isConfigured;
}
