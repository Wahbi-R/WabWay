import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/app_profile.dart';
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

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      // 1. Find the profile
      final profile = await TripMemberService.findProfileByEmail(email);
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _loading = false;
          _error = 'No Wabway account found for "$email". They need to sign up first.';
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
                'They must already have a Wabway account. After being added, the trip will appear when they next log in.',
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
