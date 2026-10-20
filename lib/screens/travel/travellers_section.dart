import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/trip/app_trip_member.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// Who's on a booking, with seats: the editor in the Add/Edit travel sheet,
// the list on the travel detail page, and the one-line summary on cards.

/// The member a traveller is assigned to, if any.
AppTripMember? _memberFor(TravelTraveller t, List<AppTripMember> members) =>
    t.userId == null ? null : members.where((m) => m.userId == t.userId).firstOrNull;

/// "You", the member's name, the name on the ticket, or null when unassigned.
String? travellerLabel(TravelTraveller t, List<AppTripMember> members, String? myId) {
  if (t.userId != null && t.userId == myId) return 'You';
  return _memberFor(t, members)?.profile.displayName ?? t.name;
}

/// One line for cards: "You · Car 14 20-D", "You, Sam +2", "4 seats".
String? travellersSummary(
    List<TravelTraveller> travellers, List<AppTripMember> members, String? myId) {
  if (travellers.isEmpty) return null;
  final mine = travellers.where((t) => t.userId != null && t.userId == myId).firstOrNull;
  if (travellers.length == 1 && mine != null) {
    return mine.seat == null ? 'You' : 'You · ${mine.seat}';
  }
  final named = [
    if (mine != null) 'You',
    for (final t in travellers)
      if (t != mine)
        if (travellerLabel(t, members, myId) case final label?) label,
  ];
  if (named.isEmpty) {
    return travellers.length == 1 ? '1 seat' : '${travellers.length} seats';
  }
  final shown = named.take(2).join(', ');
  final more = travellers.length - named.take(2).length;
  return more > 0 ? '$shown +$more' : shown;
}

// ─── Detail page list ─────────────────────────────────────────────────────────

class TravellersList extends ConsumerWidget {
  const TravellersList({super.key, required this.travellers});

  final List<TravelTraveller> travellers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (travellers.isEmpty) return const SizedBox.shrink();
    final members = ref.watch(tripMembersProvider);
    final myId = ref.watch(profileProvider)?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Who's travelling", style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        DecoratedBox(
          decoration: BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < travellers.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: kColorBorder),
                _TravellerRow(
                  traveller: travellers[i],
                  member: _memberFor(travellers[i], members),
                  label: travellerLabel(travellers[i], members, myId),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TravellerRow extends StatelessWidget {
  const _TravellerRow({required this.traveller, this.member, this.label});

  final TravelTraveller traveller;
  final AppTripMember? member;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final onTicket = traveller.name != null && member != null ? traveller.name : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
      child: Row(
        children: [
          _TravellerAvatar(name: member?.profile.displayName ?? traveller.name),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label ?? 'Not assigned yet',
                    style: label == null
                        ? kStyleBody.copyWith(color: kColorInkSoft)
                        : kStyleBodyMedium),
                if (onTicket != null)
                  Text('On ticket: $onTicket',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
              ],
            ),
          ),
          if (traveller.seat != null) ...[
            const SizedBox(width: kSpace2),
            Text(traveller.seat!, style: kStyleBodyMedium),
          ],
        ],
      ),
    );
  }
}

class _TravellerAvatar extends StatelessWidget {
  const _TravellerAvatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) => name == null
      ? Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: kColorSurfaceSunken, shape: BoxShape.circle),
          child: const Icon(Icons.event_seat_rounded, size: 16, color: kColorInkSoft),
        )
      : WabwayAvatar(name: name!, size: WabwayAvatarSize.sm);
}

// ─── Editor (Add / Edit travel sheet) ─────────────────────────────────────────

/// Pick who's on the booking and their seats. Rows from a scanned ticket can
/// arrive unassigned (seat only) or with just the printed name; each row's
/// person picker assigns them to a trip member.
class TravellersEditor extends ConsumerStatefulWidget {
  const TravellersEditor({super.key, required this.travellers, required this.onChanged});

  final List<TravelTraveller> travellers;
  final ValueChanged<List<TravelTraveller>> onChanged;

  @override
  ConsumerState<TravellersEditor> createState() => _TravellersEditorState();
}

class _TravellersEditorState extends ConsumerState<TravellersEditor> {
  late List<TravelTraveller> _rows = [...widget.travellers];
  late final List<TextEditingController> _seatCtrls = [
    for (final t in widget.travellers) TextEditingController(text: t.seat ?? ''),
  ];

  @override
  void dispose() {
    for (final c in _seatCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(List.unmodifiable(_rows));

  void _add(String? userId) {
    setState(() {
      _rows = [..._rows, TravelTraveller(userId: userId)];
      _seatCtrls.add(TextEditingController());
    });
    _emit();
  }

  void _remove(int i) {
    setState(() {
      _rows = [..._rows]..removeAt(i);
      _seatCtrls.removeAt(i).dispose();
    });
    _emit();
  }

  void _update(int i, TravelTraveller t) {
    setState(() => _rows = [..._rows]..[i] = t);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(tripMembersProvider);
    final myId = ref.watch(profileProvider)?.id;
    final taken = {for (final t in _rows) t.userId};
    final missing = members.where((m) => !taken.contains(m.userId)).toList();
    String nameOf(AppTripMember m) => m.userId == myId ? 'You' : m.profile.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Who's travelling (optional)",
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        for (var i = 0; i < _rows.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: WabwaySelectField<String>(
                  hint: _rows[i].name != null ? 'On ticket: ${_rows[i].name}' : 'Who?',
                  value: _rows[i].userId,
                  items: [
                    for (final m in members)
                      if (m.userId == _rows[i].userId || !taken.contains(m.userId))
                        WabwaySelectItem(value: m.userId, label: nameOf(m)),
                  ],
                  onChanged: (id) => _update(i, _rows[i].copyWith(userId: id)),
                ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                flex: 2,
                child: WabwayTextField(
                  hint: 'Seat',
                  controller: _seatCtrls[i],
                  textInputAction: TextInputAction.next,
                  onChanged: (v) => _update(
                      i, _rows[i].copyWith(seat: v.trim().isEmpty ? null : v.trim())),
                ),
              ),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Remove',
                onPressed: () => _remove(i),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
        ],
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: [
            if (missing.length > 1)
              WabwayButton(
                label: _rows.isEmpty ? 'Everyone' : 'Everyone else',
                icon: Icons.group_add_rounded,
                variant: WabwayButtonVariant.secondary,
                size: WabwayButtonSize.sm,
                onPressed: () {
                  for (final m in missing) {
                    _add(m.userId);
                  }
                },
              ),
            WabwayButton(
              label: 'Add person',
              icon: Icons.person_add_alt_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _add(
                  _rows.isEmpty && missing.any((m) => m.userId == myId) ? myId : null),
            ),
          ],
        ),
      ],
    );
  }
}
