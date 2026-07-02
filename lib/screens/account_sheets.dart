import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/wabway_button.dart';
import '../widgets/wabway_text_field.dart';

void showEditNameSheet(BuildContext context) {
  final profile = ProfileState.maybeOf(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditNameSheet(
      initialName: profile?.displayName ?? '',
      onSaved: () => ProfileState.refresh(context),
    ),
  );
}

void showSetPasswordSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SetPasswordSheet(),
  );
}

// ─── Edit name sheet ──────────────────────────────────────────────────────────

class _EditNameSheet extends StatefulWidget {
  const _EditNameSheet({required this.initialName, required this.onSaved});
  final String initialName;
  final VoidCallback onSaved;

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService.updateDisplayName(name);
      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Edit name',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WabwayTextField(
            label: 'Display name',
            controller: _ctrl,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            error: _error,
          ),
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Save',
            onPressed: _loading ? null : _save,
            loading: _loading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

// ─── Set / change password sheet ─────────────────────────────────────────────

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet();

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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
    return _Sheet(
      title: _done ? 'Password saved' : 'Set / change password',
      child: _done
          ? Column(
              children: [
                const Icon(Icons.check_circle_rounded, color: kColorSuccess, size: 40),
                const SizedBox(height: kSpace3),
                Text(
                  'You can now sign in with your email and password.',
                  style: kStyleCaption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: kSpace4),
                WabwayButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                  fullWidth: true,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WabwayTextField(
                  label: 'New password',
                  controller: _ctrl,
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  error: _error,
                ),
                const SizedBox(height: kSpace4),
                WabwayButton(
                  label: 'Save password',
                  onPressed: _loading ? null : _save,
                  loading: _loading,
                  fullWidth: true,
                ),
              ],
            ),
    );
  }
}

// ─── Sheet wrapper ────────────────────────────────────────────────────────────

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace6, kSpace5, kSpace6, kSpace8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: kColorBorder,
                    borderRadius: kRadiusPill,
                  ),
                ),
              ),
              const SizedBox(height: kSpace4),
              Text(title, style: kStyleTitle),
              const SizedBox(height: kSpace5),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
