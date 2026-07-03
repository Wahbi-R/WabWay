import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/app_profile.dart';
import '../../core/auth/profile_state.dart';
import '../../core/debug/app_logger.dart';
import '../../core/supabase/auth_service.dart';
import '../../core/supabase/client.dart';
import '../trips/trip_gate.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/wabway_button.dart';
import '../../widgets/wabway_text_field.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final StreamSubscription<AuthState> _sub;
  AppProfile? _profile;
  bool _loading = true;
  bool _showPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _sub = supabase.auth.onAuthStateChange.listen(_onAuthChange);

    final session = supabase.auth.currentSession;
    if (session != null) {
      _fetchProfile(session.user.id);
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onAuthChange(AuthState state) {
    AppLogger.instance.log('authStateChange → ${state.event}  uid=${state.session?.user.id}', tag: 'AUTH');
    switch (state.event) {
      case AuthChangeEvent.passwordRecovery:
        // User clicked a password-reset link — show the set-new-password form.
        if (mounted) setState(() { _showPasswordRecovery = true; _loading = false; });
      case AuthChangeEvent.signedIn:
        final uid = state.session?.user.id;
        if (uid != null && _profile == null) _fetchProfile(uid);
      case AuthChangeEvent.signedOut:
        if (mounted) {
          setState(() { _profile = null; _loading = false; _showPasswordRecovery = false; });
        }
      default:
        break;
    }
  }

  Future<void> _fetchProfile(String userId) async {
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      final profile = data != null
          ? AppProfile.fromMap(data)
          : AppProfile(
              id: userId,
              displayName: supabase.auth.currentUser?.userMetadata?['display_name']
                      as String?
                  ?? supabase.auth.currentUser?.email?.split('@').first
                  ?? 'Traveller',
              displayNameIsSet:
                  supabase.auth.currentUser?.userMetadata?['display_name'] != null,
              email: supabase.auth.currentUser?.email ?? '',
            );

      setState(() { _profile = profile; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setDisplayName(String name) async {
    await AuthService.updateDisplayName(name);
    if (!mounted) return;
    setState(() {
      _profile = _profile?.copyWith(displayName: name, displayNameIsSet: true);
    });
  }

  void _refreshProfile() {
    final uid = _profile?.id ?? supabase.auth.currentUser?.id;
    if (uid != null) _fetchProfile(uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();

    if (_showPasswordRecovery) {
      return _PasswordRecoveryScreen(
        onDone: () => setState(() {
          _showPasswordRecovery = false;
          // Profile may already be loaded from a prior session.
          if (_profile == null) {
            final uid = supabase.auth.currentUser?.id;
            if (uid != null) _fetchProfile(uid);
          }
        }),
      );
    }

    if (_profile != null) {
      if (!_profile!.displayNameIsSet) {
        return _NamePromptScreen(onNameSet: _setDisplayName);
      }
      return ProfileState(
        profile: _profile!,
        onRefresh: _refreshProfile,
        child: const TripGate(),
      );
    }

    return const SignInScreen();
  }
}

// ─── Splash ───────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: kColorPrimary,
                borderRadius: kRadiusMd,
              ),
              child: Center(
                child: Text(
                  'W',
                  style: kStyleTitle.copyWith(
                    color: kColorTextOnPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: kSpace6),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(kColorPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Name prompt (first sign-in via magic link) ───────────────────────────────

class _NamePromptScreen extends StatefulWidget {
  const _NamePromptScreen({required this.onNameSet});
  final Future<void> Function(String name) onNameSet;

  @override
  State<_NamePromptScreen> createState() => _NamePromptScreenState();
}

class _NamePromptScreenState extends State<_NamePromptScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.onNameSet(name);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(kSpace6),
            child: DecoratedBox(
              decoration: kCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(kSpace6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('What should we call you?', style: kStyleTitle),
                    const SizedBox(height: 4),
                    Text(
                      'This is how you\'ll appear to your travel group.',
                      style: kStyleCaption,
                    ),
                    const SizedBox(height: kSpace5),
                    WabwayTextField(
                      label: 'Your name',
                      hint: 'e.g. Alex',
                      controller: _ctrl,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      error: _error,
                    ),
                    const SizedBox(height: kSpace4),
                    WabwayButton(
                      label: 'Continue',
                      onPressed: _loading ? null : _submit,
                      loading: _loading,
                      fullWidth: true,
                      size: WabwayButtonSize.lg,
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

// ─── Password recovery (after clicking reset link) ────────────────────────────

class _PasswordRecoveryScreen extends StatefulWidget {
  const _PasswordRecoveryScreen({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<_PasswordRecoveryScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _ctrl.text;
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.updatePassword(pw);
      if (mounted) setState(() { _loading = false; _done = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(kSpace6),
            child: DecoratedBox(
              decoration: kCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(kSpace6),
                child: _done ? _DoneState(onContinue: widget.onDone) : _FormState(
                  ctrl: _ctrl,
                  loading: _loading,
                  error: _error,
                  onSubmit: _submit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormState extends StatelessWidget {
  const _FormState({
    required this.ctrl,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });
  final TextEditingController ctrl;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Set a new password', style: kStyleTitle),
        const SizedBox(height: 4),
        Text('Choose a password you\'ll use to sign in.', style: kStyleCaption),
        const SizedBox(height: kSpace5),
        WabwayTextField(
          label: 'New password',
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          error: error,
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: 'Save password',
          onPressed: loading ? null : onSubmit,
          loading: loading,
          fullWidth: true,
          size: WabwayButtonSize.lg,
        ),
      ],
    );
  }
}

class _DoneState extends StatelessWidget {
  const _DoneState({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: kColorSuccessSoft,
            borderRadius: kRadiusMd,
          ),
          child: const Icon(Icons.check_rounded, color: kColorSuccess, size: 24),
        ),
        const SizedBox(height: kSpace4),
        Text('Password saved', style: kStyleTitle, textAlign: TextAlign.center),
        const SizedBox(height: kSpace2),
        Text('You can now sign in with your email and password.', style: kStyleCaption, textAlign: TextAlign.center),
        const SizedBox(height: kSpace5),
        WabwayButton(
          label: 'Continue',
          onPressed: onContinue,
          fullWidth: true,
          size: WabwayButtonSize.lg,
        ),
      ],
    );
  }
}
