import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/learning_profile.dart';

typedef LearningHomeBuilder =
    Widget Function(
      LearningProfile profile,
      LearningProfileRepository profiles,
    );

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.homeBuilder});

  final LearningHomeBuilder homeBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _profiles = LearningProfileRepository();
  bool _showAuthentication = false;
  bool _createAccount = true;
  User? _profileUser;
  Future<LearningProfile>? _profileFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _StartupError();
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          if (_showAuthentication) {
            return AuthenticationScreen(
              createAccount: _createAccount,
              onBack: () => setState(() => _showAuthentication = false),
            );
          }
          return IntroScreen(
            onCreateAccount: () => setState(() {
              _createAccount = true;
              _showAuthentication = true;
            }),
            onSignIn: () => setState(() {
              _createAccount = false;
              _showAuthentication = true;
            }),
          );
        }

        if (_profileUser?.uid != user.uid) {
          _profileUser = user;
          _profileFuture = _loadProfile(user);
        }
        return FutureBuilder<LearningProfile>(
          future: _profileFuture,
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return const _StartupError();
            }
            if (!profileSnapshot.hasData) {
              return const _LoadingScreen();
            }
            return widget.homeBuilder(profileSnapshot.data!, _profiles);
          },
        );
      },
    );
  }

  Future<LearningProfile> _loadProfile(User user) async {
    try {
      return await _profiles.loadOrCreate(user);
    } catch (error, stackTrace) {
      debugPrint('Learning profile load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}

class IntroScreen extends StatelessWidget {
  const IntroScreen({
    super.key,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/brand/mozhi_mithram_logo.png',
                      width: 66,
                      height: 66,
                      semanticLabel: 'Mozhi Mithram app logo',
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Mozhi Mithram',
                    style: TextStyle(
                      color: Color(0xFF202A25),
                      fontSize: 31,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Build confident, natural speech with a tutor that adapts to you.',
                    style: TextStyle(
                      color: Color(0xFF66716A),
                      height: 1.45,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _IntroFeature(
                    icon: Icons.translate_rounded,
                    title: 'Learn through Malayalam',
                  ),
                  const _IntroFeature(
                    icon: Icons.auto_awesome_rounded,
                    title: 'Practice at your pace',
                  ),
                  const _IntroFeature(
                    icon: Icons.trending_up_rounded,
                    title: 'Build a learning streak',
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onCreateAccount,
                    style: _primaryButtonStyle(),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onSignIn,
                    style: _outlinedButtonStyle(),
                    child: const Text('I already have an account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroFeature extends StatelessWidget {
  const _IntroFeature({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF23745B), size: 21),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF303A34),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({
    super.key,
    required this.onBack,
    required this.createAccount,
  });

  final VoidCallback onBack;
  final bool createAccount;

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late bool _creatingAccount;
  bool _passwordVisible = false;
  bool _busy = false;
  String? _errorMessage;

  static Future<void>? _googleInitialization;

  // Google OAuth Web client ID from the Firebase/Google Cloud project.
  static const _googleServerClientId =
      '558968627249-g5r66v0kesg3krss564p6ekbdeu23gud.apps.googleusercontent.com';

  @override
  void initState() {
    super.initState();
    _creatingAccount = widget.createAccount;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      if (_creatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        await credential.user?.updateDisplayName(_nameController.text.trim());
        await credential.user?.reload();
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'FirebaseAuth email flow failed: ${error.code} - ${error.message}',
      );
      setState(() => _errorMessage = _friendlyAuthError(error.code));
    } catch (error) {
      debugPrint('FirebaseAuth email flow unexpected error: $error');
      setState(
        () => _errorMessage =
            'Could not connect. Check your internet and try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        !kIsWeb) {
      setState(() {
        _errorMessage =
            'Google sign-in is currently only supported on Android, iOS, and web.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final google = GoogleSignIn.instance;
      _googleInitialization ??= google.initialize(
        serverClientId: _googleServerClientId,
      );
      await _googleInitialization;
      final account = await google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google did not return an ID token.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        debugPrint(
          'GoogleSignInException: ${error.code} - ${error.description}',
        );
        setState(() {
          _errorMessage =
              'Google sign-in is not fully configured yet. Check the Google provider and OAuth client settings in Firebase.';
        });
      }
    } catch (error) {
      debugPrint('Google sign-in unexpected error: $error');
      setState(() {
        _errorMessage =
            'Google sign-in is not fully configured yet. Check the Google provider and OAuth client settings in Firebase.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _creatingAccount = !_creatingAccount;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: widget.onBack,
                        tooltip: 'Back',
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _creatingAccount ? 'Create your account' : 'Welcome back',
                      style: const TextStyle(
                        color: Color(0xFF202A25),
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _creatingAccount
                          ? 'Your lessons and progress will be saved to your account.'
                          : 'Sign in to continue your learning journey.',
                      style: const TextStyle(
                        color: Color(0xFF737B75),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_creatingAccount) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: _fieldDecoration('Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter your name'
                            : null,
                      ),
                      const SizedBox(height: 13),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: _fieldDecoration('Email'),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)
                            ? null
                            : 'Enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 13),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_passwordVisible,
                      autofillHints: _creatingAccount
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      decoration: _fieldDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _passwordVisible
                              ? 'Hide password'
                              : 'Show password',
                          onPressed: () => setState(
                            () => _passwordVisible = !_passwordVisible,
                          ),
                          icon: Icon(
                            _passwordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final password = value ?? '';
                        if (_creatingAccount && password.length < 8) {
                          return 'Use at least 8 characters';
                        }
                        return password.isEmpty ? 'Enter your password' : null;
                      },
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFB33B2E),
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submitEmail,
                      style: _primaryButtonStyle(),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _creatingAccount ? 'Create account' : 'Sign in',
                            ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('OR'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signInWithGoogle,
                      style: _outlinedButtonStyle(),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 27),
                      label: const Text('Continue with Google'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _busy ? null : _toggleMode,
                      child: Text(
                        _creatingAccount
                            ? 'Already registered? Sign in'
                            : 'New to Mozhi Mithram? Create an account',
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Your password is managed securely by Firebase Authentication.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF737B75), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: Color(0xFFE4E7E2)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: Color(0xFFE4E7E2)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(13),
    borderSide: const BorderSide(color: Color(0xFF23745B), width: 1.5),
  ),
);

ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
  backgroundColor: const Color(0xFF23745B),
  foregroundColor: Colors.white,
  minimumSize: const Size.fromHeight(52),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  textStyle: const TextStyle(fontWeight: FontWeight.w800),
);

ButtonStyle _outlinedButtonStyle() => OutlinedButton.styleFrom(
  foregroundColor: const Color(0xFF202A25),
  minimumSize: const Size.fromHeight(50),
  side: const BorderSide(color: Color(0xFFD8DED8)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
);

String _friendlyAuthError(String code) => switch (code) {
  'email-already-in-use' => 'An account already exists for this email.',
  'invalid-email' => 'Enter a valid email address.',
  'user-not-found' ||
  'wrong-password' ||
  'invalid-credential' => 'Email or password is incorrect.',
  'weak-password' => 'Choose a stronger password.',
  'too-many-requests' => 'Too many attempts. Try again later.',
  'network-request-failed' => 'Network error. Check your connection.',
  'operation-not-allowed' =>
    'Email sign-in is not enabled in Firebase Authentication yet.',
  _ => 'Authentication failed. Please try again.',
};

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF23745B))),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not connect to your account. Check the Firebase configuration and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
