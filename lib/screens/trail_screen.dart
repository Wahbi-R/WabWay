import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/async_screen_mixin.dart';
import '../core/notifications/push_notifier.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/trail/trail_mode.dart';
import '../core/trip/app_trip_member.dart';
import '../data/date_utils.dart';
import '../data/spot_data.dart' show fmtCommentTime;
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/wabway_avatar.dart';
import '../widgets/wabway_button.dart';
import '../widgets/wabway_empty_state.dart';
import '../widgets/wabway_error_state.dart';
import '../widgets/wabway_snack.dart';
import 'notification_settings_screen.dart' show kPrefNotifCrew;

/// Trail mode: arrows and distances to the crew with no signal (hiking,
/// festivals, anywhere off-grid). See [TrailMode].
class TrailScreen extends ConsumerStatefulWidget {
  const TrailScreen({super.key});

  @override
  ConsumerState<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends ConsumerState<TrailScreen>
    with AsyncScreenMixin, WidgetsBindingObserver {
  final _trail = TrailMode.instance;
  TrailSetup _setup = const TrailSetup();
  TrailState _state = const TrailState();
  double? _heading;
  bool _starting = false;
  StreamSubscription<TrailState>? _stateSub;
  StreamSubscription<double>? _headingSub;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (!TrailMode.supported) {
      loading = false;
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _stateSub = _trail.states.listen((s) {
      if (mounted) setState(() => _state = s);
    }, onError: (_) {});
    _headingSub = _trail.heading.listen((h) {
      if (mounted) setState(() => _heading = h);
    }, onError: (_) {});
    // "2m ago" labels keep moving even when nothing new is heard.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateSub?.cancel();
    _headingSub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  // Back from Settings (battery, permissions, Bluetooth) — re-check.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load(silent: true);
  }

  Future<void> _configure() async {
    final tripId = ref.read(activeTripIdProvider);
    final me = ref.read(profileProvider)?.id;
    final members = ref.read(tripMembersProvider);
    if (tripId.isEmpty || me == null || members.isEmpty) return;
    await _trail.configure(tripId: tripId, members: members, myUserId: me);
  }

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      await _configure();
      final setup = await _trail.setup();
      commitLoad(gen, () => _setup = setup);
    } catch (_) {
      failLoad(gen, silent: silent, message: "Couldn't check Bluetooth and location on this phone.");
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await _configure();
      var setup = await _trail.setup();
      if (!setup.bluetoothPermission || !setup.locationPermission) {
        await _trail.requestPermissions();
        setup = await _trail.setup();
      }
      if (!setup.bluetoothPermission || !setup.locationPermission) {
        _snack('Trail mode needs "Nearby devices" and location — allow them in Settings.');
        await _trail.openAppSettings();
        return;
      }
      if (!setup.bluetoothOn) {
        await _trail.enableBluetooth();
        _snack('Turn on Bluetooth, then tap Start again.');
        return;
      }
      if (!setup.locationOn) {
        _snack('GPS is off — your crew will only see roughly where you are.');
      }
      await _trail.start();
      _announce();
      if (mounted) setState(() => _setup = setup);
    } catch (_) {
      _snack("Couldn't start Trail mode on this phone.");
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// While there's still signal (e.g. at the trailhead), tell the crew to join.
  /// With no signal this quietly fails — nearby phones wake up over Bluetooth.
  void _announce() {
    final tripId = ref.read(activeTripIdProvider);
    final me = ref.read(profileProvider);
    if (tripId.isEmpty || me == null) return;
    pushNotify(
      tripId: tripId,
      title: '\u{1F97E} ${me.displayName} turned on Trail mode',
      body: 'Tap to turn yours on so you can find each other without signal',
      excludeUserId: me.id,
      data: {'screen': 'trail', 'trip_id': tripId},
      prefKey: kPrefNotifCrew,
    );
  }

  Future<void> _stop() async {
    await _trail.stop();
    _snack("Trail mode is off. Crew nearby won't turn it back on for 2 hours — you'll get a notification instead.");
  }

  Future<void> _setWake(bool v) async {
    await _trail.setWake(v);
    if (!mounted) return;
    setState(() => _state = TrailState(
          running: _state.running, startedAt: _state.startedAt, wokenBy: _state.wokenBy,
          wake: v, me: _state.me, peers: _state.peers));
  }

  void _snack(String m) {
    if (mounted) showWabwaySnack(context, m);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(tripMembersProvider);
    ref.listen<List<AppTripMember>>(tripMembersProvider, (_, __) => _configure());
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Trail mode', style: kStyleTitle),
        backgroundColor: kColorPaper,
        surfaceTintColor: Colors.transparent,
      ),
      body: _body(members),
    );
  }

  Widget _body(List<AppTripMember> members) {
    if (!TrailMode.supported) {
      return const WabwayEmptyState(
        icon: Icons.hiking_rounded,
        title: 'Trail mode is in the Android app',
        description: 'It uses your phone\'s Bluetooth and GPS to find the crew with no signal.',
      );
    }
    if (loading) return const Center(child: CircularProgressIndicator(color: kColorPrimary));
    if (error) {
      return WabwayErrorState(
        title: "Couldn't set up Trail mode",
        description: errorMessage.isNotEmpty ? errorMessage : 'Try again.',
        action: WabwayButton(label: 'Retry', onPressed: _load),
      );
    }
    if (!_setup.supported) {
      return const WabwayEmptyState(
        icon: Icons.bluetooth_disabled_rounded,
        title: "This phone can't do Trail mode",
        description: 'It needs Bluetooth Low Energy (Android 8 or newer).',
      );
    }
    final myId = ref.read(profileProvider)?.id;
    final crew = TrailMode.sortedCrew(members);
    final others = [
      for (var i = 0; i < crew.length; i++)
        if (crew[i].userId != myId) (index: i, member: crew[i]),
    ];
    return RefreshIndicator(
      color: kColorPrimary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace10),
        children: [
          _statusCard(),
          const SizedBox(height: kSpace3),
          _SetupCard(setup: _setup, trail: _trail, onChanged: () => _load(silent: true)),
          _wakeCard(),
          const SizedBox(height: kSpace4),
          _myFixLine(),
          const SizedBox(height: kSpace2),
          for (final o in others) ...[
            _CrewTile(
              member: o.member,
              peer: _state.peer(o.index),
              me: _state.me,
              heading: _heading,
              running: _state.running,
            ),
            const SizedBox(height: kSpace2),
          ],
          if (others.isEmpty)
            Text('Nobody else is on this trip yet.', style: kStyleCaption.copyWith(color: kColorInkSoft)),
          const SizedBox(height: kSpace4),
          _HowItWorks(),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final on = _state.running;
    final since = _state.startedAt;
    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: on ? kColorSuccessSoft : kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: on ? kColorSuccessBorder : kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.hiking_rounded, color: on ? kColorSuccess : kColorPrimary),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Text(on ? 'Trail mode is on' : 'Find your crew with no signal', style: kStyleBodySemibold),
            ),
          ]),
          const SizedBox(height: kSpace2),
          Text(
            on
                ? [
                    if (_state.wokenBy != null) '${_state.wokenBy} turned it on nearby, so yours came on too.',
                    if (since != null)
                      'On since ${fmtTimeOfDay(since.hour, since.minute)} · turns itself off after 6 hours.',
                  ].join(' ')
                : 'Your phones share where everyone is over Bluetooth — no signal needed. '
                    'Start it before you lose signal and the crew gets a notification to join.',
            style: kStyleCaption.copyWith(color: kColorInk),
          ),
          const SizedBox(height: kSpace3),
          on
              ? WabwayButton(
                  label: 'Stop Trail mode',
                  variant: WabwayButtonVariant.dangerOutline,
                  fullWidth: true,
                  onPressed: _stop,
                )
              : WabwayButton(
                  label: 'Start Trail mode',
                  icon: Icons.play_arrow_rounded,
                  fullWidth: true,
                  loading: _starting,
                  onPressed: _starting ? null : _start,
                ),
        ],
      ),
    );
  }

  Widget _wakeCard() {
    return SwitchListTile.adaptive(
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace1),
      activeTrackColor: kColorPrimary,
      title: Text('Let the crew wake me', style: kStyleBodyMedium),
      subtitle: Text(
        _setup.canWake || !_state.wake
            ? "When someone nearby starts Trail mode, yours turns on too — even with the app closed. "
                'Uses almost no battery until then.'
            : 'Fix the steps above so this phone can turn it on by itself. '
                "Until then you'll get a \"tap to join\" notification.",
        style: kStyleCaption.copyWith(color: kColorInkSoft),
      ),
      value: _state.wake,
      onChanged: _setWake,
    );
  }

  Widget _myFixLine() {
    final me = _state.me;
    final String text;
    if (me == null) {
      text = _state.running ? 'Waiting for GPS… (works best outside)' : 'Your crew';
    } else {
      final age = DateTime.now().difference(me.time);
      text = 'Your GPS: ±${me.accuracyM} m · ${age.inSeconds < 60 ? 'just now' : fmtCommentTime(me.time)}';
    }
    return Row(children: [
      Text(_state.running || me != null ? 'YOUR CREW' : '', style: kStyleOverline.copyWith(color: kColorInkSoft)),
      const Spacer(),
      Flexible(
        child: Text(text,
            style: kStyleCaption.copyWith(color: kColorInkSoft),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

// ─── Setup checklist ──────────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.setup, required this.trail, required this.onChanged});
  final TrailSetup setup;
  final TrailMode trail;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final steps = <({String title, String detail, Future<void> Function() fix})>[
      if (!setup.bluetoothPermission || !setup.locationPermission)
        (
          title: 'Allow Nearby devices and location',
          detail: 'So your phone can talk to the crew\'s phones and know where you are.',
          fix: () async {
            await trail.requestPermissions();
          },
        ),
      if (!setup.bluetoothOn)
        (title: 'Turn on Bluetooth', detail: 'Leave it on during the hike.', fix: trail.enableBluetooth),
      if (!setup.locationOn)
        (title: 'Turn on location (GPS)', detail: 'GPS works with no signal.', fix: trail.openLocationSettings),
      if (setup.locationPermission && !setup.backgroundLocation)
        (
          title: 'Location: Allow all the time',
          detail: 'Lets Trail mode turn on by itself in your pocket.',
          fix: () async {
            await trail.requestBackgroundLocation();
          },
        ),
      if (!setup.batteryUnrestricted)
        (
          title: 'Battery: Unrestricted',
          detail: 'Samsung puts apps to sleep. Also add WabWay to Settings → Battery → '
              'Background usage limits → Never sleeping apps.',
          fix: trail.requestBatteryUnrestricted,
        ),
      if (!setup.notifications)
        (
          title: 'Allow notifications',
          detail: 'To hear when someone nearby turns on Trail mode.',
          fix: () async {
            await trail.requestPermissions();
          },
        ),
    ];
    if (steps.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: kSpace2),
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kColorWarningSoft,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorWarningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set up this phone', style: kStyleBodySemibold),
          const SizedBox(height: kSpace2),
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.radio_button_unchecked_rounded, size: 16, color: kColorWarning),
                  ),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title, style: kStyleBodyMedium),
                        Text(s.detail, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                      ],
                    ),
                  ),
                  WabwayButton(
                    label: 'Fix',
                    size: WabwayButtonSize.sm,
                    variant: WabwayButtonVariant.secondary,
                    onPressed: () async {
                      await s.fix();
                      onChanged();
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── One crew member ─────────────────────────────────────────────────────────

class _CrewTile extends StatelessWidget {
  const _CrewTile({
    required this.member,
    required this.peer,
    required this.me,
    required this.heading,
    required this.running,
  });

  final AppTripMember member;
  final TrailPeer? peer;
  final TrailFix? me;
  final double? heading;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final p = peer;
    final v = trailVector(me, p?.fix);
    final now = DateTime.now();
    final live = p != null && !p.relayed && now.difference(p.heardAt) < const Duration(seconds: 45);

    final String status;
    if (p == null) {
      status = running ? 'Not in range yet' : 'Not seen';
    } else if (p.fix == null) {
      status = live && p.rssi != null ? '${signalLabel(p.rssi!)} · no GPS on their phone yet' : 'Heard ${fmtCommentTime(p.heardAt)} · no GPS';
    } else {
      final when = now.difference(p.fix!.time) < const Duration(seconds: 60) ? 'just now' : fmtCommentTime(p.fix!.time);
      final acc = me != null ? ' · ±${combinedAccuracy(me!, p.fix!)} m' : '';
      status = live
          ? 'Live$acc'
          : p.relayed
              ? 'Via ${p.viaName ?? 'the crew'} · $when$acc'
              : 'Last seen $when$acc';
    }

    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: live ? kColorSuccessBorder : kColorBorder),
      ),
      child: Row(
        children: [
          WabwayAvatar(
            name: member.profile.displayName,
            src: member.profile.avatarUrl != null ? NetworkImage(member.profile.avatarUrl!) : null,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.profile.displayName, style: kStyleBodySemibold, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  if (live) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(color: kColorSuccess, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(status,
                        style: kStyleCaption.copyWith(color: live ? kColorSuccess : kColorInkSoft),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2),
                  ),
                ]),
              ],
            ),
          ),
          if (v != null) _Pointer(metres: v.metres, bearing: v.bearing, heading: heading),
        ],
      ),
    );
  }
}

/// Arrow that points at them as you turn (needs a compass), plus distance.
class _Pointer extends StatelessWidget {
  const _Pointer({required this.metres, required this.bearing, required this.heading});
  final double metres;
  final double bearing;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final h = heading;
    final dist = metres < 1000 ? '${(metres / 5).round() * 5} m' : '${(metres / 1000).toStringAsFixed(1)} km';
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          AnimatedRotation(
            turns: ((h == null ? bearing : bearing - h) % 360) / 360,
            duration: const Duration(milliseconds: 250),
            child: Icon(Icons.navigation_rounded, size: 30, color: h == null ? kColorInkSoft : kColorPrimary),
          ),
          Text(dist, style: kStyleBodySemibold),
          Text(compassPoint(bearing),
              style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11)),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lines = [
      'Phones hear each other up to roughly 50–100 m in the open, less in thick forest.',
      'Positions hop: if you can hear Ana and Ana heard Sam, you see Sam too (a bit older).',
      'Out of range? You still get their last position and which way it was.',
      'Hold the phone flat so the arrow points the right way.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW IT WORKS', style: kStyleOverline.copyWith(color: kColorInkSoft)),
        const SizedBox(height: kSpace2),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('•  ', style: kStyleCaption.copyWith(color: kColorInkSoft)),
              Expanded(child: Text(l, style: kStyleCaption.copyWith(color: kColorInkSoft))),
            ]),
          ),
      ],
    );
  }
}
