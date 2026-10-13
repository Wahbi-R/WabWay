import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/app_profile.dart';
import '../../core/supabase/invite_service.dart';
import '../../core/supabase/trip_member_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'package:flutter/services.dart';
import '../../data/invite_data.dart';
import 'invite_sheet.dart';

Future<void> showAddMemberSheet(
  BuildContext context, {
  required String tripId,
  required Set<String> existingMemberIds,
  required VoidCallback onMemberAdded,
}) {
  return showWabwayAutoSheet<void>(
    context,
    builder: (_, handle) => _AddMemberSheet(
      tripId: tripId,
      existingMemberIds: existingMemberIds,
      onMemberAdded: onMemberAdded,
      showDragHandle: handle,
    ),
  );
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({
    required this.tripId,
    required this.existingMemberIds,
    required this.onMemberAdded,
    this.showDragHandle = true,
  });

  final String tripId;
  final Set<String> existingMemberIds;
  final VoidCallback onMemberAdded;
  final bool showDragHandle;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  AppProfile? _added;
  String? _notFoundEmail;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() { _loading = true; _error = null; _notFoundEmail = null; });

    try {
      // 1. Find the profile
      final profile = await TripMemberService.findProfileByEmail(email);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _loading = false;
          _notFoundEmail = email;
        });
        return;
      }

      // 2. Client-side duplicate check
      if (widget.existingMemberIds.contains(profile.id)) {
        setState(() {
          _loading = false;
          _error = '${profile.displayName} is already a member of this trip.';
        });
        return;
      }

      // 3. Add to trip_members
      await TripMemberService.addMember(
        tripId: widget.tripId,
        userId: profile.id,
      );
      if (!mounted) return;

      widget.onMemberAdded();
      setState(() { _loading = false; _added = profile; });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.code == '23505'
          ? 'This person is already a member of the trip.'
          : 'Something went wrong. Please try again.';
      setState(() { _loading = false; _error = msg; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, kSpace6 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showDragHandle) const WabwayDragHandle(),
            const SizedBox(height: kSpace3),

            Row(
              children: [
                Text('Add a member', style: kStyleTitle),
                const Spacer(),
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: kSpace5),

            if (_added != null)
              _SuccessState(member: _added!, onDone: () => Navigator.pop(context))
            else if (_notFoundEmail != null)
              _EmailInviteState(
                email: _notFoundEmail!,
                tripId: widget.tripId,
                onBack: () {
                  final email = _notFoundEmail!;
                  setState(() { _notFoundEmail = null; });
                  _emailCtrl.text = email;
                },
                onDone: () => Navigator.pop(context),
              )
            else ...[
              WabwayTextField(
                label: 'Email address',
                hint: 'friend@example.com',
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofocus: true,
                onSubmitted: (_) => _submit(),
              ),

              if (_error != null) ...[
                const SizedBox(height: kSpace3),
                Text(_error!, style: kStyleCaption.copyWith(color: kColorDanger)),
              ],

              const SizedBox(height: kSpace4),
              WabwayButton(
                label: 'Add member',
                icon: Icons.person_add_rounded,
                fullWidth: true,
                size: WabwayButtonSize.lg,
                loading: _loading,
                onPressed: _loading ? null : _submit,
              ),
              const SizedBox(height: kSpace3),
              Text(
                'If they don\'t have an account yet, use the email option below.',
                style: kStyleCaption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmailInviteState extends StatefulWidget {
  const _EmailInviteState({
    required this.email,
    required this.tripId,
    required this.onBack,
    required this.onDone,
  });

  final String email;
  final String tripId;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  State<_EmailInviteState> createState() => _EmailInviteStateState();
}

class _EmailInviteStateState extends State<_EmailInviteState> {
  InviteCode? _code;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _create();
  }

  // Create the code up front so it's always visible — never hidden inside a
  // mail app that may not exist on this device.
  Future<void> _create() async {
    setState(() => _error = null);
    try {
      final code = await InviteService.createInvite(widget.tripId);
      if (mounted) setState(() => _code = code);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create an invite code. Check your connection and try again.');
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code!.code));
    if (!mounted) return;
    setState(() => _copied = true);
    showWabwaySnack(context, 'Code copied');
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: widget.email,
      query: 'subject=${Uri.encodeComponent('Join my trip on WabWay!')}'
          '&body=${Uri.encodeComponent(inviteMessage(_code!))}',
    );
    final ok = await canLaunchUrl(uri) && await launchUrl(uri);
    if (!ok && mounted) {
      showWabwaySnack(context, 'No mail app found — share or copy the code instead.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('No WabWay account yet', style: kStyleTitle, textAlign: TextAlign.center),
        const SizedBox(height: kSpace2),
        Text(
          "${widget.email} isn't on WabWay yet. Send them this code — once they sign up and enter it, they'll join the trip.",
          style: kStyleCaption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpace5),
        if (_error != null) ...[
          Text(_error!, style: kStyleCaption.copyWith(color: kColorDanger), textAlign: TextAlign.center),
          const SizedBox(height: kSpace3),
          WabwayButton(label: 'Try again', variant: WabwayButtonVariant.ghost, onPressed: _create),
        ] else if (code == null)
          const Center(
            child: Padding(padding: EdgeInsets.all(kSpace4), child: CircularProgressIndicator()),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: kSpace4),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(color: kColorBorder),
            ),
            child: SelectableText(
              code.displayCode,
              textAlign: TextAlign.center,
              style: kStyleTitle.copyWith(letterSpacing: 4),
            ),
          ),
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Share invite',
            icon: Icons.ios_share_rounded,
            fullWidth: true,
            size: WabwayButtonSize.lg,
            onPressed: () => shareInviteCode(code),
          ),
          const SizedBox(height: kSpace2),
          Row(
            children: [
              Expanded(
                child: WabwayButton(
                  label: _copied ? 'Copied' : 'Copy code',
                  icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                  variant: WabwayButtonVariant.ghost,
                  onPressed: _copy,
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                child: WabwayButton(
                  label: 'Email it',
                  icon: Icons.email_rounded,
                  variant: WabwayButtonVariant.ghost,
                  onPressed: _email,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: kSpace3),
        WabwayButton(
          label: 'Try a different email',
          variant: WabwayButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onBack,
        ),
        const SizedBox(height: kSpace2),
        WabwayButton(
          label: 'Done',
          variant: WabwayButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onDone,
        ),
      ],
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.member, required this.onDone});
  final AppProfile member;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: kColorSuccessSoft,
            borderRadius: kRadiusMd,
          ),
          child: const Icon(Icons.check_rounded, color: kColorSuccess, size: 28),
        ),
        const SizedBox(height: kSpace4),
        Text('Member added!', style: kStyleTitle, textAlign: TextAlign.center),
        const SizedBox(height: kSpace2),
        Text(
          '${member.displayName} (${member.email}) has been added to the trip. They\'ll see it next time they log in.',
          style: kStyleCaption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpace5),
        WabwayButton(
          label: 'Done',
          fullWidth: true,
          size: WabwayButtonSize.lg,
          onPressed: onDone,
        ),
      ],
    );
  }
}
