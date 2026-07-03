import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/trip/app_trip.dart';
import '../../core/trip/app_trip_member.dart';
import '../../core/trip/trip_state.dart';
import '../../core/supabase/invite_service.dart';
import '../../core/supabase/trip_service.dart';
import '../../shell/app_shell.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'create_trip_screen.dart';

class TripGate extends StatefulWidget {
  const TripGate({super.key});

  @override
  State<TripGate> createState() => _TripGateState();
}

class _TripGateState extends State<TripGate> {
  bool _loading = true;
  bool _error = false;
  List<AppTrip> _trips = [];
  List<AppTripMember> _members = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = false; });
    try {
      final trips = await TripService.loadUserTrips();
      if (!mounted) return;
      if (trips.isEmpty) {
        setState(() { _trips = []; _loading = false; });
        return;
      }
      final members = await TripService.loadTripMembers(trips.first.id);
      if (!mounted) return;
      setState(() { _trips = trips; _members = members; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _onTripCreated(String tripId) async => _load();
  Future<void> _onTripJoined(String tripId) async => _load();

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _TripLoadingScreen();
    if (_error)   return _ErrorScreen(onRetry: _load);

    if (_trips.isEmpty) {
      return _NoTripsScreen(
        onTripCreated: _onTripCreated,
        onTripJoined: _onTripJoined,
      );
    }

    return TripState(
      trip: _trips.first,
      members: _members,
      onRefresh: _load,
      child: const AppShell(),
    );
  }
}

// ─── No trips ─────────────────────────────────────────────────────────────────

class _NoTripsScreen extends StatelessWidget {
  const _NoTripsScreen({
    required this.onTripCreated,
    required this.onTripJoined,
  });

  final Future<void> Function(String tripId) onTripCreated;
  final Future<void> Function(String tripId) onTripJoined;

  Future<void> _openJoinSheet(BuildContext context) async {
    final tripId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JoinWithCodeSheet(),
    );
    if (tripId != null) {
      await onTripJoined(tripId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(kSpace6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: kColorPrimary,
                          borderRadius: kRadiusMd,
                        ),
                        child: Center(
                          child: Text(
                            'W',
                            style: kStyleTitle.copyWith(
                              color: kColorTextOnPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace6),
                  Text(
                    'Where are you headed?',
                    style: kStyleTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    'Start planning a new trip, or join one a friend has already created.',
                    style: kStyleCaption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: kSpace6),
                  WabwayButton(
                    label: 'Create a trip',
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateTripScreen(onCreated: onTripCreated),
                      ),
                    ),
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    icon: Icons.add_rounded,
                  ),
                  const SizedBox(height: kSpace3),
                  WabwayButton(
                    label: 'Join with an invite code',
                    variant: WabwayButtonVariant.secondary,
                    onPressed: () => _openJoinSheet(context),
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    icon: Icons.group_add_rounded,
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

// ─── Join-with-code sheet ─────────────────────────────────────────────────────

class _JoinWithCodeSheet extends StatefulWidget {
  const _JoinWithCodeSheet();

  @override
  State<_JoinWithCodeSheet> createState() => _JoinWithCodeSheetState();
}

class _JoinWithCodeSheetState extends State<_JoinWithCodeSheet> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    try {
      final tripId = await InviteService.redeemInvite(code);
      if (!mounted) return;
      Navigator.pop(context, tripId);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'P0002'
          ? 'This code is invalid or has expired. Check the code and try again.'
          : 'Something went wrong. Please try again.';
      setState(() { _loading = false; _error = msg; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Something went wrong. Please try again.'; });
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
                Text('Join a trip', style: kStyleTitle),
                const Spacer(),
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: kSpace5),

            WabwayTextField(
              label: 'Invite code',
              hint: 'e.g. ABCD1234',
              controller: _codeCtrl,
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
              label: 'Join trip',
              icon: Icons.group_add_rounded,
              fullWidth: true,
              size: WabwayButtonSize.lg,
              loading: _loading,
              onPressed: _loading ? null : _submit,
            ),
            const SizedBox(height: kSpace3),
            Text(
              'Ask the trip organiser to share an invite code with you.',
              style: kStyleCaption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Loading ──────────────────────────────────────────────────────────────────

class _TripLoadingScreen extends StatelessWidget {
  const _TripLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(kColorPrimary),
          ),
        ),
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(kSpace6),
            child: DecoratedBox(
              decoration: kCardDecoration(),
              child: Padding(
                padding: const EdgeInsets.all(kSpace6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: kColorDangerSoft,
                        borderRadius: kRadiusMd,
                      ),
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: kColorDanger,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: kSpace4),
                    Text(
                      'Could not load trips',
                      style: kStyleTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpace2),
                    Text(
                      'Check your connection and try again.',
                      style: kStyleCaption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: kSpace5),
                    WabwayButton(
                      label: 'Try again',
                      onPressed: onRetry,
                      fullWidth: true,
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
