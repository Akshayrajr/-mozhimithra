import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/learning_profile.dart';
import '../data/vocabulary.dart';

typedef ProfileSaveCallback =
    Future<LearningProfile> Function({
      required String displayName,
      required String targetLanguage,
      required String tutorLanguage,
      required int dailyGoalMinutes,
      required String skillLevel,
      XFile? photo,
      required bool removePhoto,
    });

typedef ProfilePhotoPicker = Future<XFile?> Function();

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.onSave,
    this.photoUrl,
    this.photoPicker,
  });

  final LearningProfile profile;
  final String? photoUrl;
  final ProfileSaveCallback onSave;
  final ProfilePhotoPicker? photoPicker;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _targetLanguage;
  late String _tutorLanguage;
  late String _skillLevel;
  late int _dailyGoalMinutes;
  XFile? _photo;
  Uint8List? _photoPreview;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _targetLanguage = widget.profile.targetLanguage;
    _tutorLanguage = widget.profile.tutorLanguage;
    _skillLevel = widget.profile.skillLevel;
    _dailyGoalMinutes = widget.profile.dailyGoalMinutes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    final picker = widget.photoPicker ?? _pickPhotoFromGallery;
    try {
      final selected = await picker();
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        _showMessage('Choose an image smaller than 5 MB.');
        return;
      }
      setState(() {
        _photo = selected;
        _photoPreview = bytes;
        _removePhoto = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Profile photo selection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage('Could not open that photo. Please try another image.');
    }
  }

  Future<XFile?> _pickPhotoFromGallery() => ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 768,
    maxHeight: 768,
    imageQuality: 85,
  );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await widget.onSave(
        displayName: _nameController.text.trim(),
        targetLanguage: _targetLanguage,
        tutorLanguage: _tutorLanguage,
        dailyGoalMinutes: _dailyGoalMinutes,
        skillLevel: _skillLevel,
        photo: _photo,
        removePhoto: _removePhoto,
      );
      if (mounted) Navigator.of(context).pop(profile);
    } catch (error, stackTrace) {
      debugPrint('Profile update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        _showMessage(
          'Could not save your profile. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? image;
    if (_photoPreview != null) {
      image = MemoryImage(_photoPreview!);
    } else if (!_removePhoto && widget.photoUrl != null) {
      image = NetworkImage(widget.photoUrl!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 54,
                      backgroundColor: const Color(0xFFDDEBE4),
                      backgroundImage: image,
                      child: image == null
                          ? Text(
                              _initials(_nameController.text),
                              style: const TextStyle(
                                color: Color(0xFF23745B),
                                fontWeight: FontWeight.w800,
                                fontSize: 34,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('profile-photo-button'),
                      onPressed: _saving ? null : _choosePhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        image == null ? 'Add profile photo' : 'Change photo',
                      ),
                    ),
                    if (image != null)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() {
                                _photo = null;
                                _photoPreview = null;
                                _removePhoto = true;
                              }),
                        child: const Text('Remove photo'),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              TextFormField(
                key: const ValueKey('profile-name-field'),
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter your name.';
                  if (name.length > 60) {
                    return 'Keep your name under 60 characters.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              _dropdown<String>(
                label: 'Learning language',
                value: _targetLanguage,
                values: supportedTargetLanguages,
                onChanged: (value) => setState(() => _targetLanguage = value),
              ),
              const SizedBox(height: 18),
              _dropdown<String>(
                label: 'Tutor explanation language',
                value: _tutorLanguage,
                values: supportedTutorLanguages,
                onChanged: (value) => setState(() => _tutorLanguage = value),
              ),
              const SizedBox(height: 18),
              _dropdown<String>(
                label: 'Speaking level',
                value: _skillLevel,
                values: const ['beginner', 'intermediate', 'advanced'],
                onChanged: (value) => setState(() => _skillLevel = value),
              ),
              const SizedBox(height: 18),
              _dropdown<int>(
                label: 'Daily speaking goal',
                value: _dailyGoalMinutes,
                values: const [10, 15, 20, 30],
                itemLabel: (value) => '$value minutes',
                onChanged: (value) => setState(() => _dailyGoalMinutes = value),
              ),
              const SizedBox(height: 28),
              FilledButton(
                key: const ValueKey('save-profile-button'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required ValueChanged<T> onChanged,
    String Function(T value)? itemLabel,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in values)
          DropdownMenuItem<T>(
            value: option,
            child: Text(itemLabel?.call(option) ?? option.toString()),
          ),
      ],
      onChanged: _saving
          ? null
          : (next) {
              if (next != null) onChanged(next);
            },
    );
  }

  String _initials(String value) {
    final name = value.trim();
    return name.isEmpty ? 'L' : name.substring(0, 1).toUpperCase();
  }
}
