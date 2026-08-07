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

Future<void> showAddMemberSheet(
  BuildContext context, {
  required String tripId,
  required Set<String> existingMemberIds,
  required VoidCallback onMemberAdded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddMemberSheet(
      tripId: tripId,
      existingMemberIds: existingMemberIds,
      onMemberAdded: onMemberAdded,
    ),
  );
}

Future<void> _sendEmailInvite(String email, String tripId) async {
  String? code;
  try {
    final invite = await InviteService.createInvite(tripId);
    code = invite.displayCode;
  } catch (_) {
    code = null;
  }

  final body = code != null
      ? Uri.encodeComponent(
          "Hey! I'm using WabWay to plan our trip and I'd love for you to join.\n\n"
          "Download the app at wabway.app, create an account, and use invite code:\n\n"
          "$code\n\n"
          "See you there!",
        )
      : Uri.encodeComponent(
          "Hey! I'm using WabWay to plan our trip and I'd love for you to join.\n\n"
          "Download the app at wabway.app and ask me for an invite code.",
        );

  final subject = Uri.encodeComponent("Join my trip on WabWay!");
  final uri = Uri.parse("mailto:$email?subject=$subject&body=$body");
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({
    required this.tripId,
    required this.existingMemberIds,
    required this.onMemberAdded,
  });

  final String tripId;
  final Set<String> existingMemberIds;
  final VoidCallback onMemberAdded;

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
            const WabwayDragHandle(),
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
  bool _sending = false;
  bool _sent = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    await _sendEmailInvite(widget.email, widget.tripId);
    if (mounted) setState(() { _sending = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: kColorSuccessSoft,
              borderRadius: kRadiusMd,
            ),
            child: const Icon(Icons.mark_email_read_rounded, color: kColorSuccess, size: 28),
          ),
          const SizedBox(height: kSpace4),
          Text('Invite sent!', style: kStyleTitle, textAlign: TextAlign.center),
          const SizedBox(height: kSpace2),
          Text(
            'We\'ve opened your mail app. Once ${widget.email} signs up and enters the code, they\'ll join the trip.',
            style: kStyleCaption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpace5),
          WabwayButton(
            label: 'Done',
            fullWidth: true,
            size: WabwayButtonSize.lg,
            onPressed: widget.onDone,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: const Icon(Icons.person_off_rounded, color: kColorInkSoft, size: 28),
        ),
        const SizedBox(height: kSpace4),
        Text(
          'No WabWay account found',
          style: kStyleTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpace2),
        Text(
          '${widget.email} doesn\'t have a WabWay account yet. Send them an email invite with a code to join.',
          style: kStyleCaption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: kSpace5),
        WabwayButton(
          label: 'Send email invite',
          icon: Icons.email_rounded,
          fullWidth: true,
          size: WabwayButtonSize.lg,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
        const SizedBox(height: kSpace3),
        WabwayButton(
          label: 'Try a different email',
          variant: WabwayButtonVariant.ghost,
          fullWidth: true,
          onPressed: widget.onBack,
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
