import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/debug/app_logger.dart';
import '../../core/supabase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/wabway_button.dart';
import '../../widgets/wabway_text_field.dart';

enum _SignInMode { magicLink, password, forgotPassword }
enum _PasswordFlow { signIn, signUp }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  _SignInMode _mode = _SignInMode.magicLink;
  _PasswordFlow _flow = _PasswordFlow.signIn;

  final _emailCtrl       = TextEditingController();
  final _passwordCtrl    = TextEditingController();
  final _displayNameCtrl = TextEditingController();

  bool    _loading            = false;
  String? _error;
  String? _rawError;
  bool    _magicSent          = false;
  bool    _passwordSignUpSent = false;
  bool    _resetSent          = false;
  bool    _alreadyExistsSent  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMagicLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.sendMagicLink(email);
      if (mounted) setState(() { _loading = false; _magicSent = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _rawError = e.toString(); _error = _friendlyError(e.toString()); });
    }
  }

  Future<void> _submitPassword() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (_flow == _PasswordFlow.signUp && _displayNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (_flow == _PasswordFlow.signIn) {
        await AuthService.signInWithPassword(email: email, password: password);
        // AuthGate stream handles navigation; reset loading in case it takes a moment.
        if (mounted) setState(() => _loading = false);
      } else {
        await AuthService.signUp(
          email: email,
          password: password,
          displayName: _displayNameCtrl.text.trim(),
        );
        // Supabase sends a confirmation email before creating a session,
        // so no signedIn event fires here — show the "check inbox" state.
        if (mounted) setState(() { _loading = false; _passwordSignUpSent = true; });
      }
    } catch (e) {
      final lower = e.toString().toLowerCase();
      // Magic link users hitting "Create account": send them a magic link so they
      // can sign in and then set their name/password from account settings.
      if (_flow == _PasswordFlow.signUp &&
          (lower.contains('user already registered') ||
           lower.contains('already been registered'))) {
        try {
          await AuthService.sendMagicLink(_emailCtrl.text.trim());
          if (mounted) setState(() { _loading = false; _alreadyExistsSent = true; });
        } catch (_) {
          if (mounted) setState(() { _loading = false; _error = _friendlyError(e.toString()); });
        }
        return;
      }
      if (mounted) setState(() { _loading = false; _error = _friendlyError(e.toString()); });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('authretryablefetchexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out')) {
      return 'Could not connect to the server. Check your internet connection and try again.';
    }
    if (lower.contains('invalid login credentials') || lower.contains('invalid_credentials')) {
      return "Incorrect email or password. If you signed up with a magic link, use that to sign in instead.";
    }
    if (lower.contains('user already registered') || lower.contains('already been registered')) {
      return "An account with this email already exists. Try signing in instead.";
    }
    return raw;
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.sendPasswordReset(email);
      if (mounted) setState(() { _loading = false; _resetSent = true; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = _friendlyError(e.toString()); });
    }
  }

  void _switchMode(_SignInMode mode) {
    setState(() {
      _mode               = mode;
      _error              = null;
      _magicSent          = false;
      _passwordSignUpSent = false;
      _resetSent          = false;
      _alreadyExistsSent  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpace6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Logo(),
                const SizedBox(height: kSpace8),
                DecoratedBox(
                  decoration: kCardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(kSpace6),
                    child: AnimatedSwitcher(
                      duration: kDurationBase,
                      child: switch (_mode) {
                        _SignInMode.magicLink => _MagicLinkForm(
                            key: const ValueKey('magic'),
                            emailCtrl: _emailCtrl,
                            loading:   _loading,
                            sent:      _magicSent,
                            error:     _error,
                            rawError:  _rawError,
                            onSend:    _sendMagicLink,
                            onSwitch:  () => _switchMode(_SignInMode.password),
                          ),
                        _SignInMode.forgotPassword => _ForgotPasswordForm(
                            key: const ValueKey('forgot'),
                            emailCtrl: _emailCtrl,
                            loading:   _loading,
                            sent:      _resetSent,
                            error:     _error,
                            onSend:    _sendPasswordReset,
                            onBack:    () => _switchMode(_SignInMode.password),
                          ),
                        _SignInMode.password => _PasswordForm(
                            key: const ValueKey('password'),
                            emailCtrl:       _emailCtrl,
                            passwordCtrl:    _passwordCtrl,
                            displayNameCtrl: _displayNameCtrl,
                            flow:              _flow,
                            loading:           _loading,
                            error:             _error,
                            signUpSent:        _passwordSignUpSent,
                            alreadyExistsSent: _alreadyExistsSent,
                            onSubmit:          _submitPassword,
                            onToggleFlow: () => setState(() {
                              _flow               = _flow == _PasswordFlow.signIn
                                  ? _PasswordFlow.signUp
                                  : _PasswordFlow.signIn;
                              _error              = null;
                              _passwordSignUpSent = false;
                              _alreadyExistsSent  = false;
                            }),
                            onSwitch:        () => _switchMode(_SignInMode.magicLink),
                            onForgotPassword: () => _switchMode(_SignInMode.forgotPassword),
                          ),
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onLongPress: () => _showLogViewer(context),
          child: Container(
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
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: kSpace3),
        Text('Wabway', style: kStyleHeadingMd),
        const SizedBox(height: 4),
        Text('Plan your trip together.', style: kStyleCaption),
      ],
    );
  }

  void _showLogViewer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogViewerSheet(),
    );
  }
}

class _LogViewerSheet extends StatefulWidget {
  const _LogViewerSheet();

  @override
  State<_LogViewerSheet> createState() => _LogViewerSheetState();
}

class _LogViewerSheetState extends State<_LogViewerSheet> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final entries = AppLogger.instance.entries;
    final dump = AppLogger.instance.dump;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text('Debug Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  const Spacer(),
                  TextButton(
                    onPressed: () { AppLogger.instance.clear(); setState(() {}); },
                    child: const Text('Clear', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: dump));
                      setState(() => _copied = true);
                      await Future<void>.delayed(const Duration(seconds: 2));
                      if (mounted) setState(() => _copied = false);
                    },
                    child: Text(
                      _copied ? 'Copied ✓' : 'Copy all',
                      style: TextStyle(
                        color: _copied ? Colors.greenAccent : Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('No logs yet.', style: TextStyle(color: Colors.white38)))
                  : ListView.builder(
                      controller: ctrl,
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      reverse: true,
                      itemBuilder: (_, i) {
                        final e = entries[entries.length - 1 - i];
                        final timeStr =
                            '${e.time.hour.toString().padLeft(2, '0')}:'
                            '${e.time.minute.toString().padLeft(2, '0')}:'
                            '${e.time.second.toString().padLeft(2, '0')}';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(timeStr, style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'monospace')),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: e.tag == 'AUTH' ? Colors.blueAccent.withValues(alpha: 0.25) : Colors.white12,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(e.tag, style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace')),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.message,
                                  style: TextStyle(
                                    color: e.message.contains('✗') ? Colors.redAccent : Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ],
                          ),
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

// ─── Magic-link form ──────────────────────────────────────────────────────────

class _MagicLinkForm extends StatelessWidget {
  const _MagicLinkForm({
    super.key,
    required this.emailCtrl,
    required this.loading,
    required this.sent,
    required this.error,
    required this.onSend,
    required this.onSwitch,
    this.rawError,
  });

  final TextEditingController emailCtrl;
  final bool loading;
  final bool sent;
  final String? error;
  final String? rawError;
  final VoidCallback onSend;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    if (sent) {
      return _SentState(
        icon: Icons.mark_email_read_rounded,
        title: 'Check your inbox',
        body: 'A sign-in link was sent to\n${emailCtrl.text.trim()}',
        linkLabel: 'Use a password instead',
        onLink: onSwitch,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sign in', style: kStyleTitle),
        const SizedBox(height: 4),
        Text(
          "We'll send a magic link to your email — no password needed.",
          style: kStyleCaption,
        ),
        const SizedBox(height: kSpace5),
        WabwayTextField(
          label: 'Email',
          hint: 'you@example.com',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          autofocus: true,
          error: error,
        ),
        if (rawError != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: rawError!));
            },
            child: Text(
              'Tap to copy error details',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], decoration: TextDecoration.underline),
            ),
          ),
        ],
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: 'Send magic link',
          onPressed: loading ? null : onSend,
          loading: loading,
          fullWidth: true,
          size: WabwayButtonSize.lg,
          icon: Icons.auto_awesome_rounded,
        ),
        const SizedBox(height: kSpace5),
        _SwitchLink(label: 'Use a password instead', onTap: onSwitch),
      ],
    );
  }
}

// ─── Password form ────────────────────────────────────────────────────────────

class _PasswordForm extends StatelessWidget {
  const _PasswordForm({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.displayNameCtrl,
    required this.flow,
    required this.loading,
    required this.error,
    required this.signUpSent,
    required this.alreadyExistsSent,
    required this.onSubmit,
    required this.onToggleFlow,
    required this.onSwitch,
    required this.onForgotPassword,
  });

  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController displayNameCtrl;
  final _PasswordFlow flow;
  final bool loading;
  final String? error;
  final bool signUpSent;
  final bool alreadyExistsSent;
  final VoidCallback onSubmit;
  final VoidCallback onToggleFlow;
  final VoidCallback onSwitch;
  final VoidCallback onForgotPassword;

  bool get _isSignUp => flow == _PasswordFlow.signUp;

  @override
  Widget build(BuildContext context) {
    if (signUpSent) {
      return _SentState(
        icon: Icons.mark_email_read_rounded,
        title: 'Confirm your email',
        body: 'We sent a confirmation link to\n${emailCtrl.text.trim()}\n\nClick it to activate your account.',
        linkLabel: 'Use a magic link instead',
        onLink: onSwitch,
      );
    }

    if (alreadyExistsSent) {
      return _SentState(
        icon: Icons.mark_email_read_rounded,
        title: 'Check your inbox',
        body: 'You already have an account with this email. We\'ve sent you a sign-in link — after signing in, you can set your name and password from account settings.',
        linkLabel: 'Use a magic link instead',
        onLink: onSwitch,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_isSignUp ? 'Create account' : 'Sign in', style: kStyleTitle),
        const SizedBox(height: 4),
        Text(
          _isSignUp
              ? 'Set a password to sign in from any device.'
              : 'Enter your email and password.',
          style: kStyleCaption,
        ),
        const SizedBox(height: kSpace5),
        if (_isSignUp) ...[
          WabwayTextField(
            label: 'Your name',
            hint: 'e.g. Alex',
            controller: displayNameCtrl,
            textInputAction: TextInputAction.next,
            autofocus: true,
          ),
          const SizedBox(height: kSpace3),
        ],
        WabwayTextField(
          label: 'Email',
          hint: 'you@example.com',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofocus: !_isSignUp,
        ),
        const SizedBox(height: kSpace3),
        WabwayTextField(
          label: 'Password',
          controller: passwordCtrl,
          obscureText: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSubmit(),
          error: error,
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: _isSignUp ? 'Create account' : 'Sign in',
          onPressed: loading ? null : onSubmit,
          loading: loading,
          fullWidth: true,
          size: WabwayButtonSize.lg,
        ),
        const SizedBox(height: kSpace4),
        _SwitchLink(
          label: _isSignUp
              ? 'Already have an account? Sign in'
              : 'New here? Create account',
          onTap: onToggleFlow,
        ),
        const SizedBox(height: kSpace3),
        if (!_isSignUp) ...[
          _SwitchLink(label: 'Forgot password?', onTap: onForgotPassword),
          const SizedBox(height: kSpace3),
        ],
        _SwitchLink(label: 'Use a magic link instead', onTap: onSwitch),
      ],
    );
  }
}

// ─── Forgot password form ─────────────────────────────────────────────────────

class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm({
    super.key,
    required this.emailCtrl,
    required this.loading,
    required this.sent,
    required this.error,
    required this.onSend,
    required this.onBack,
  });

  final TextEditingController emailCtrl;
  final bool loading;
  final bool sent;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    if (sent) {
      return _SentState(
        icon: Icons.mark_email_read_rounded,
        title: 'Check your inbox',
        body: 'A password reset link was sent to\n${emailCtrl.text.trim()}',
        linkLabel: 'Back to sign in',
        onLink: onBack,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Forgot password?', style: kStyleTitle),
        const SizedBox(height: 4),
        Text("Enter your email and we'll send a reset link.", style: kStyleCaption),
        const SizedBox(height: kSpace5),
        WabwayTextField(
          label: 'Email',
          hint: 'you@example.com',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onSend(),
          autofocus: true,
          error: error,
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: 'Send reset link',
          onPressed: loading ? null : onSend,
          loading: loading,
          fullWidth: true,
          size: WabwayButtonSize.lg,
        ),
        const SizedBox(height: kSpace5),
        _SwitchLink(label: 'Back to sign in', onTap: onBack),
      ],
    );
  }
}

// ─── Reusable "sent" confirmation state ───────────────────────────────────────

class _SentState extends StatelessWidget {
  const _SentState({
    required this.icon,
    required this.title,
    required this.body,
    required this.linkLabel,
    required this.onLink,
  });

  final IconData icon;
  final String title;
  final String body;
  final String linkLabel;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: kColorSuccessSoft,
            borderRadius: kRadiusMd,
          ),
          child: Icon(icon, color: kColorSuccess, size: 24),
        ),
        const SizedBox(height: kSpace4),
        Text(title, style: kStyleTitle, textAlign: TextAlign.center),
        const SizedBox(height: kSpace2),
        Text(body, style: kStyleCaption, textAlign: TextAlign.center),
        const SizedBox(height: kSpace5),
        _SwitchLink(label: linkLabel, onTap: onLink),
      ],
    );
  }
}

// ─── Shared helper ────────────────────────────────────────────────────────────

class _SwitchLink extends StatelessWidget {
  const _SwitchLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: kStyleCaption.copyWith(
          color: kColorPrimary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: kColorPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
