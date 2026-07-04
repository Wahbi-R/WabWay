import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase/invite_service.dart';
import '../../data/invite_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

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
  List<InviteCode> _codes = [];
  bool _loading = true;
  bool _generating = false;
  String? _error;
  final Set<String> _copied = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final codes = await InviteService.loadInvites(widget.tripId);
      if (!mounted) return;
      setState(() { _codes = codes; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load invite codes.'; });
    }
  }

  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });
    try {
      final code = await InviteService.createInvite(widget.tripId);
      if (!mounted) return;
      setState(() { _codes = [code, ..._codes]; _generating = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Could not generate a code. Try again.';
      });
    }
  }

  Future<void> _revoke(InviteCode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Revoke code?', style: kStyleBodySemibold),
        content: Text(
          '"${code.displayCode}" will stop working immediately.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Revoke', style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _codes = _codes.where((c) => c.id != code.id).toList());
    try {
      await InviteService.revokeInvite(code.id);
    } catch (_) {
      if (mounted) _load();
    }
  }

  Future<void> _copy(InviteCode code) async {
    await Clipboard.setData(ClipboardData(text: code.code));
    if (!mounted) return;
    setState(() => _copied.add(code.id));
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied.remove(code.id));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const WabwayDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, 0),
              child: Row(
                children: [
                  Text('Invite codes', style: kStyleTitle),
                  const Spacer(),
                  WabwayIconButton(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: kSpace5),
            Flexible(
              child: ListView(
                controller: ctrl,
                padding: EdgeInsets.fromLTRB(
                  kSpace5,
                  0,
                  kSpace5,
                  kSpace6 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(
                    'Share a code with anyone you want to join the trip. '
                    'Codes are single-use and expire after 7 days.',
                    style: kStyleCaption,
                  ),
                  const SizedBox(height: kSpace5),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(kSpace6),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null) ...[
                    Text(_error!,
                        style: kStyleCaption.copyWith(color: kColorDanger)),
                    const SizedBox(height: kSpace3),
                    WabwayButton(
                      label: 'Retry',
                      fullWidth: true,
                      onPressed: _load,
                    ),
                  ] else
                    _CodesSection(
                      codes: _codes,
                      copied: _copied,
                      onCopy: _copy,
                      onRevoke: _revoke,
                    ),

                  WabwayButton(
                    label: 'Generate new code',
                    icon: Icons.add_rounded,
                    fullWidth: true,
                    loading: _generating,
                    onPressed: _generating ? null : _generate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Codes section ────────────────────────────────────────────────────────────

class _CodesSection extends StatelessWidget {
  const _CodesSection({
    required this.codes,
    required this.copied,
    required this.onCopy,
    required this.onRevoke,
  });

  final List<InviteCode> codes;
  final Set<String> copied;
  final Future<void> Function(InviteCode) onCopy;
  final Future<void> Function(InviteCode) onRevoke;

  @override
  Widget build(BuildContext context) {
    final active   = codes.where((c) => c.isActive).toList();
    final inactive = codes.where((c) => !c.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active.isNotEmpty) ...[
          Text('Active', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          ...active.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: kSpace3),
                child: _CodeCard(
                  code: c,
                  copied: copied.contains(c.id),
                  onCopy: () => onCopy(c),
                  onRevoke: () => onRevoke(c),
                ),
              )),
          const SizedBox(height: kSpace3),
        ],
        if (inactive.isNotEmpty) ...[
          Text('Used / expired', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          ...inactive.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: kSpace3),
                child: _CodeCard(
                  code: c,
                  copied: false,
                  onCopy: null,
                  onRevoke: null,
                ),
              )),
          const SizedBox(height: kSpace3),
        ],
        if (codes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace4),
            child: Center(
              child: Text('No invite codes yet.', style: kStyleCaption),
            ),
          ),
      ],
    );
  }
}

// ─── Code card ────────────────────────────────────────────────────────────────

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.copied,
    required this.onCopy,
    required this.onRevoke,
  });

  final InviteCode code;
  final bool copied;
  final VoidCallback? onCopy;
  final VoidCallback? onRevoke;

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = code.isActive;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? kColorSurfaceSunken : kColorBgRaised,
        borderRadius: kRadiusMd,
        border: Border.all(
          color: isActive ? kColorBorder : kColorBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  code.displayCode,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kTextXl,
                    fontWeight: FontWeight.w700,
                    color: isActive ? kColorInk : kColorInkSoft,
                    letterSpacing: 4,
                  ),
                ),
                const Spacer(),
                if (code.isUsed)
                  _Badge(label: 'Used', color: kColorSuccess)
                else if (code.isExpired)
                  _Badge(label: 'Expired', color: kColorDanger)
                else
                  _Badge(label: 'Active', color: kColorPrimary),
              ],
            ),
            const SizedBox(height: kSpace2),
            Text(
              'Expires ${_fmtDate(code.expiresAt)}',
              style: kStyleCaption.copyWith(
                color: isActive ? kColorInkSoft : kColorInkSoft.withValues(alpha: 0.6),
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: kSpace3),
              Row(
                children: [
                  Expanded(
                    child: WabwayButton(
                      label: copied ? 'Copied!' : 'Copy',
                      icon: copied
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      size: WabwayButtonSize.sm,
                      onPressed: onCopy,
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  WabwayButton(
                    label: 'Revoke',
                    icon: Icons.block_rounded,
                    size: WabwayButtonSize.sm,
                    variant: WabwayButtonVariant.danger,
                    onPressed: onRevoke,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: kRadiusPill,
      ),
      child: Text(
        label,
        style: kStyleOverline.copyWith(color: color),
      ),
    );
  }
}
