import 'package:flutter/material.dart';
import '../../core/trip/app_trip.dart';
import '../../core/trip/trip_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'create_trip_screen.dart';
import 'trip_gate.dart';

Future<void> showTripSwitcherSheet(BuildContext context) {
  // Capture TripState before pushing modal
  final currentTripId = TripState.tripOf(context).id;
  final allTrips      = TripState.allTripsOf(context);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TripSwitcherSheet(
      currentTripId: currentTripId,
      allTrips:      allTrips,
      onSwitch: (trip) {
        Navigator.pop(ctx);
        TripState.switchTrip(context, trip);
      },
      onCreateTrip: () {
        Navigator.pop(ctx);
        Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => CreateTripScreen(
            onCreated: (_) async => TripState.refresh(context),
          ),
        ));
      },
      onJoinTrip: () {
        Navigator.pop(ctx);
        _showJoinSheet(context);
      },
    ),
  );
}

void _showJoinSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JoinTripProxy(onJoined: () => TripState.refresh(context)),
  );
}

// ─── Sheet ───────────────────────────────────────────────────────────────────

class _TripSwitcherSheet extends StatelessWidget {
  const _TripSwitcherSheet({
    required this.currentTripId,
    required this.allTrips,
    required this.onSwitch,
    required this.onCreateTrip,
    required this.onJoinTrip,
  });

  final String currentTripId;
  final List<AppTrip> allTrips;
  final ValueChanged<AppTrip> onSwitch;
  final VoidCallback onCreateTrip;
  final VoidCallback onJoinTrip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4,
          kSpace3,
          kSpace4,
          kSpace6 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),

            Row(
              children: [
                Text('Your trips', style: kStyleTitle),
                const Spacer(),
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: kSpace4),

            // Trip list
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Column(
                children: allTrips.asMap().entries.map((e) {
                  final i    = e.key;
                  final trip = e.value;
                  final isActive = trip.id == currentTripId;
                  final isLast   = i == allTrips.length - 1;

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: kSpace4,
                          vertical: kSpace2,
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? kColorPrimary : kColorSurfaceSunken,
                            borderRadius: kRadiusMd,
                          ),
                          child: Center(
                            child: Text(
                              trip.name.isNotEmpty
                                  ? trip.name[0].toUpperCase()
                                  : 'T',
                              style: kStyleBodySemibold.copyWith(
                                color: isActive ? Colors.white : kColorInkSoft,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          trip.name,
                          style: kStyleBodyMedium.copyWith(
                            color: isActive ? kColorPrimary : kColorInk,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        subtitle: trip.destination != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(trip.destination!, style: kStyleCaption),
                              )
                            : null,
                        trailing: isActive
                            ? const Icon(Icons.check_circle_rounded,
                                color: kColorPrimary, size: 20)
                            : Icon(Icons.chevron_right_rounded,
                                color: kColorTextTertiary(), size: 18),
                        onTap: isActive ? null : () => onSwitch(trip),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: kSpace4),

            // Create / join
            Row(
              children: [
                Expanded(
                  child: WabwayButton(
                    label: 'Create trip',
                    icon: Icons.add_rounded,
                    variant: WabwayButtonVariant.secondary,
                    onPressed: onCreateTrip,
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: WabwayButton(
                    label: 'Join trip',
                    icon: Icons.group_add_rounded,
                    variant: WabwayButtonVariant.secondary,
                    onPressed: onJoinTrip,
                    fullWidth: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Minimal join-code sheet proxy ────────────────────────────────────────────
// Reuses the _JoinWithCodeSheet from trip_gate.dart by re-exporting a thin wrapper.

class _JoinTripProxy extends StatelessWidget {
  const _JoinTripProxy({required this.onJoined});
  final VoidCallback onJoined;

  @override
  Widget build(BuildContext context) {
    return const JoinWithCodeSheet();
  }
}
