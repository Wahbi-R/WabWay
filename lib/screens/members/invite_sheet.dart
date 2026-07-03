import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase/invite_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Shows a bottom sheet that generates and displays an invite code for [tripId].
/// Only call this when the current user is the trip owner.
Future<void> showInviteSheet(BuildContext context, {required String tripId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InviteSheet(tripId: tripId),
  );
}

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.tripId});
  final String tripId;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  String? _code;
  bool _loading = true;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _error = null; });
    try {
      final code = await InviteService.createInvite(widget.tripId);
      if (!mounted) return;
      setState(() { _code = code; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not generate an invite code. Try again.';
        _loading = false;
      });
    }
  }

  Future<void> _copy() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: _code!));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, kSpace6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),

            Row(
              children: [
                Text('Invite code', style: kStyleTitle),
                const Spacer(),
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: kSpace2),
            Text(
              'Share this code with anyone you want to join the trip. '
              'Valid for 7 days.',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace5),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: kSpace6),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_error != null)
              _ErrorState(message: _error!, onRetry: _generate)
            else
              _CodeDisplay(code: _code!, copied: _copied, onCopy: _copy),
          ],
        ),
      ),
    );
  }
}

// ─── Code display ─────────────────────────────────────────────────────────────

class _CodeDisplay extends StatelessWidget {
  const _CodeDisplay({
    required this.code,
    required this.copied,
    required this.onCopy,
  });

  final String code;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    // Format 8-char code as "XXXX XXXX" for easier reading / transcribing.
    final display = code.length == 8
        ? '${code.substring(0, 4)} ${code.substring(4)}'
        : code;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace6),
            child: Center(
              child: Text(
                display,
                style: GoogleFonts.ibmPlexMono(
                  fontSize: kText2xl,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: kSpace4),
        WabwayButton(
          label: copied ? 'Copied!' : 'Copy code',
          icon: copied ? Icons.check_rounded : Icons.copy_rounded,
          fullWidth: true,
          size: WabwayButtonSize.lg,
          onPressed: onCopy,
        ),
      ],
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: kStyleCaption.copyWith(color: kColorDanger)),
        const SizedBox(height: kSpace3),
        WabwayButton(
          label: 'Try again',
          fullWidth: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
