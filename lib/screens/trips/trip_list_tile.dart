import 'package:flutter/material.dart';
import '../../core/text_utils.dart';
import '../../core/trip/app_trip.dart';
import '../../data/date_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

/// The one trip row: initials tile, name, destination · dates subtitle, and a
/// check for the active trip. Used by the trip switcher and Home.
class TripListTile extends StatelessWidget {
  const TripListTile({
    super.key,
    required this.trip,
    required this.isActive,
    this.onTap,
  });

  final AppTrip trip;
  final bool isActive;
  final VoidCallback? onTap;

  static String subtitleFor(AppTrip t) {
    final parts = <String>[
      if (t.destination != null && t.destination!.trim().isNotEmpty) t.destination!.trim(),
      if (t.startDate != null && t.endDate != null) fmtDateRange(t.startDate!, t.endDate!)
      else if (t.startDate != null) fmtDate(t.startDate!),
    ];
    return parts.isEmpty ? 'No destination or dates yet' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? kColorPrimary : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
        ),
        child: Center(
          child: Text(
            initialsFor(trip.name),
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(subtitleFor(trip), style: kStyleCaption),
      ),
      trailing: isActive
          ? const Icon(Icons.check_circle_rounded, color: kColorPrimary, size: 20)
          : Icon(Icons.chevron_right_rounded, color: kColorTextTertiary(), size: 18),
      onTap: onTap,
    );
  }
}
