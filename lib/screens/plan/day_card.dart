import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/trip/app_trip_member.dart';
import '../../data/money_data.dart' show fmtAmount;
import '../../data/plan_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'item_tile.dart';

// ─── Trip day card ────────────────────────────────────────────────────────────

class TripDayCard extends StatefulWidget {
  const TripDayCard({
    super.key,
    required this.day,
    this.selectedItemId,
    required this.onItemTap,
    required this.onAddItem,
    this.isDesktop = false,
    this.onDayTap,
    this.daySelected = false,
    this.onEditDay,
    this.onDeleteDay,
    this.onCopyDay,
    this.onReorder,
    this.onToggleDone,
    this.hideCompleted = false,
    this.forceCollapsed,
  });

  final TripDay day;
  final String? selectedItemId;
  final ValueChanged<String> onItemTap;
  final VoidCallback onAddItem;
  final bool isDesktop;
  final VoidCallback? onDayTap;
  final bool daySelected;
  final VoidCallback? onEditDay;
  final VoidCallback? onDeleteDay;
  final VoidCallback? onCopyDay;
  final ValueChanged<List<ItineraryItem>>? onReorder;
  final ValueChanged<String>? onToggleDone;
  final bool hideCompleted;
  final bool? forceCollapsed;

  @override
  State<TripDayCard> createState() => _TripDayCardState();
}

class _TripDayCardState extends State<TripDayCard> {
  bool _notesExpanded = false;
  bool _itemsCollapsed = false;

  @override
  void didUpdateWidget(TripDayCard old) {
    super.didUpdateWidget(old);
    if (widget.forceCollapsed != null && widget.forceCollapsed != old.forceCollapsed) {
      _itemsCollapsed = widget.forceCollapsed!;
    }
  }

  void _handleHeaderTap() {
    if (widget.isDesktop) {
      widget.onDayTap?.call();
    } else {
      setState(() => _notesExpanded = !_notesExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = widget.day.sortedItems;
    final items = widget.hideCompleted
        ? allItems.where((i) => !i.isDone).toList()
        : allItems;
    final hasNotes = widget.day.notes != null && widget.day.notes!.isNotEmpty;
    final headerTappable =
        hasNotes || (widget.isDesktop && widget.onDayTap != null);

    return WabwayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DayHeader(
            day: widget.day,
            expanded: _notesExpanded,
            hasNotes: hasNotes,
            isDesktop: widget.isDesktop,
            selected: widget.daySelected,
            isCollapsed: _itemsCollapsed,
            onCollapseToggle: items.isNotEmpty
                ? () => setState(() => _itemsCollapsed = !_itemsCollapsed)
                : null,
            onTap: headerTappable ? _handleHeaderTap : null,
            onEdit: widget.onEditDay,
            onCopy: widget.onCopyDay,
            onDelete: widget.onDeleteDay,
          ),
          if (!_itemsCollapsed) ...[
            const Divider(height: 1, color: kColorBorder),
            if (items.isEmpty)
              _EmptyDayBody(onAddItem: widget.onAddItem)
            else if (widget.onReorder != null)
              _ReorderableItemList(
                items: items,
                selectedItemId: widget.selectedItemId,
                onItemTap: widget.onItemTap,
                onAddItem: widget.onAddItem,
                onReorder: widget.onReorder!,
                onToggleDone: widget.onToggleDone,
              )
            else
              Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    ItineraryItemTile(
                      item: items[i],
                      isLast: i == items.length - 1,
                      selected: items[i].id == widget.selectedItemId,
                      onTap: () => widget.onItemTap(items[i].id),
                      onToggleDone: widget.onToggleDone != null
                          ? () => widget.onToggleDone!(items[i].id)
                          : null,
                    ),
                    if (i < items.length - 1)
                      const Divider(
                        height: 1,
                        indent: kSpace4 + 50 + kSpace3 + 10 + kSpace3,
                        color: kColorBorder,
                      ),
                  ],
                  const Divider(height: 1, color: kColorBorder),
                  _DayCostFooter(items: items),
                  _AddItemRow(onTap: widget.onAddItem),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

enum _DayMenuAction { edit, copy, delete }

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.expanded,
    required this.hasNotes,
    required this.isDesktop,
    required this.selected,
    required this.isCollapsed,
    this.onCollapseToggle,
    this.onTap,
    this.onEdit,
    this.onCopy,
    this.onDelete,
  });

  final TripDay day;
  final bool expanded;
  final bool hasNotes;
  final bool isDesktop;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback? onCollapseToggle;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Day number circle
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: selected ? kColorPrimary : kColorPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.dayNumber}',
                    style: kStyleCaptionMedium.copyWith(
                      color: selected ? kColorTextOnPrimary : kColorPrimaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: kSpace3),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Day ${day.dayNumber}',
                            style: kStyleBodySemibold.copyWith(
                              color: selected ? kColorPrimary : kColorInk,
                            )),
                        const SizedBox(width: kSpace2),
                        Text('·',
                            style:
                                kStyleCaption.copyWith(color: kColorInkSoft)),
                        const SizedBox(width: kSpace2),
                        Flexible(
                          child: Text(
                            fmtDate(day.date),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: kTextSm,
                              fontWeight: FontWeight.w500,
                              color: kColorInkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_city_rounded,
                            size: 11, color: kColorInkSoft),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            day.city,
                            style: kStyleCaption.copyWith(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Inline truncated notes (hidden when expanded)
                        if (hasNotes && !expanded) ...[
                          Flexible(
                            child: Text(
                              '  ·  ${day.notes}',
                              style: kStyleCaption.copyWith(
                                  fontSize: 11, color: kColorInkSoft),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        // Expand chevron (mobile only)
                        if (hasNotes && !isDesktop) ...[
                          const SizedBox(width: 2),
                          Icon(
                            expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 14,
                            color: kColorInkSoft,
                          ),
                        ],
                      ],
                    ),
                    // Time span row — shown when ≥2 items have a time set
                    Builder(builder: (context) {
                      final timed = day.items.where((i) => i.time != null).toList()
                        ..sort((a, b) => a.time!.compareTo(b.time!));
                      if (timed.length < 2) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 11, color: kColorInkSoft),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                '${timed.first.time} → ${timed.last.time}',
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: kColorInkSoft,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Per-day planned cost total (hidden when no costs are set).
              Builder(builder: (context) {
                final Map<String, double> dayCosts = {};
                for (final item in day.items) {
                  if (item.plannedCost != null && item.plannedCost! > 0) {
                    final c = item.currency ?? '';
                    dayCosts[c] = (dayCosts[c] ?? 0) + item.plannedCost!;
                  }
                }
                if (dayCosts.isEmpty) return const SizedBox.shrink();
                final label = dayCosts.entries
                    .map((e) => fmtAmount(e.value, e.key))
                    .join(' + ');
                return Padding(
                  padding: const EdgeInsets.only(right: kSpace2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: kColorPrimary.withValues(alpha: 0.08),
                      borderRadius: kRadiusPill,
                      border: Border.all(color: kColorPrimary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      label,
                      style: kStyleCaption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kColorPrimary,
                      ),
                    ),
                  ),
                );
              }),

              // Completion badge — shows "X/Y done" when some are checked off,
              // plain count when none are done yet.
              if (day.items.isNotEmpty)
                Builder(builder: (context) {
                  final done  = day.items.where((i) => i.isDone).length;
                  final total = day.items.length;
                  final allDone = done == total;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: allDone
                          ? kColorPrimary.withValues(alpha: 0.12)
                          : kColorSurfaceSunken,
                      borderRadius: kRadiusPill,
                    ),
                    child: Text(
                      done > 0 ? '$done/$total' : '$total',
                      style: kStyleCaption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: allDone ? kColorPrimary : kColorInkSoft,
                      ),
                    ),
                  );
                }),
              if (onCollapseToggle != null) ...[
                const SizedBox(width: kSpace1),
                GestureDetector(
                  onTap: onCollapseToggle,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      isCollapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      size: 18,
                      color: kColorInkSoft,
                    ),
                  ),
                ),
              ],
              if (onEdit != null || onCopy != null || onDelete != null) ...[
                const SizedBox(width: kSpace2),
                PopupMenuButton<_DayMenuAction>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  iconColor: kColorInkSoft,
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    if (action == _DayMenuAction.edit)   onEdit?.call();
                    if (action == _DayMenuAction.copy)   onCopy?.call();
                    if (action == _DayMenuAction.delete) onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: _DayMenuAction.edit,
                        child: Row(children: [
                          Icon(Icons.edit_outlined, size: 16),
                          SizedBox(width: 10),
                          Text('Edit day'),
                        ]),
                      ),
                    if (onCopy != null)
                      const PopupMenuItem(
                        value: _DayMenuAction.copy,
                        child: Row(children: [
                          Icon(Icons.copy_rounded, size: 16),
                          SizedBox(width: 10),
                          Text('Copy day as text'),
                        ]),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: _DayMenuAction.delete,
                        child: Row(children: [
                          Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete day', style: TextStyle(color: Colors.red)),
                        ]),
                      ),
                  ],
                ),
              ],
            ],
          ),

          // Expanded full notes (mobile tap-to-expand)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: hasNotes && expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: kSpace2, left: 38),
                    child: Text(
                      day.notes!,
                      style: kStyleCaption.copyWith(
                        color: kColorInkSoft,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          _MemberPresenceRow(date: day.date),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: content,
      );
    }
    return content;
  }
}

// ─── Empty day body ───────────────────────────────────────────────────────────

class _EmptyDayBody extends StatelessWidget {
  const _EmptyDayBody({required this.onAddItem});
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: kSpace5, horizontal: kSpace4),
      child: Column(
        children: [
          Text(
            'No plans yet',
            style: kStyleCaption.copyWith(color: kColorInkSoft),
          ),
          const SizedBox(height: kSpace3),
          WabwayButton(
            label: 'Add item',
            icon: Icons.add_rounded,
            variant: WabwayButtonVariant.ghost,
            size: WabwayButtonSize.sm,
            onPressed: onAddItem,
          ),
        ],
      ),
    );
  }
}

// ─── Reorderable item list ────────────────────────────────────────────────────

class _ReorderableItemList extends StatefulWidget {
  const _ReorderableItemList({
    required this.items,
    required this.selectedItemId,
    required this.onItemTap,
    required this.onAddItem,
    required this.onReorder,
    this.onToggleDone,
  });

  final List<ItineraryItem> items;
  final String? selectedItemId;
  final ValueChanged<String> onItemTap;
  final VoidCallback onAddItem;
  final ValueChanged<List<ItineraryItem>> onReorder;
  final ValueChanged<String>? onToggleDone;

  @override
  State<_ReorderableItemList> createState() => _ReorderableItemListState();
}

class _ReorderableItemListState extends State<_ReorderableItemList> {
  late List<ItineraryItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  @override
  void didUpdateWidget(_ReorderableItemList old) {
    super.didUpdateWidget(old);
    if (widget.items != old.items) _items = List.of(widget.items);
  }

  void _handleReorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
    widget.onReorder(_items);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _items.length,
          onReorder: _handleReorder,
          proxyDecorator: (child, index, animation) => Material(
            elevation: 3,
            color: Colors.transparent,
            child: child,
          ),
          itemBuilder: (_, i) {
            final item = _items[i];
            final isLast = i == _items.length - 1;
            return Column(
              key: ValueKey(item.id),
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: kSpace2, vertical: kSpace3),
                        child: Icon(Icons.drag_handle_rounded,
                            size: 18, color: kColorBorder),
                      ),
                    ),
                    Expanded(
                      child: ItineraryItemTile(
                        item: item,
                        isLast: isLast,
                        selected: item.id == widget.selectedItemId,
                        onTap: () => widget.onItemTap(item.id),
                        onToggleDone: widget.onToggleDone != null
                            ? () => widget.onToggleDone!(item.id)
                            : null,
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  const Divider(
                    height: 1,
                    indent: kSpace2 + 18 + kSpace2 + kSpace4 + 50 + kSpace3 + 10 + kSpace3,
                    color: kColorBorder,
                  ),
              ],
            );
          },
        ),
        const Divider(height: 1, color: kColorBorder),
        _DayCostFooter(items: widget.items),
        _AddItemRow(onTap: widget.onAddItem),
      ],
    );
  }
}

// ─── Day cost footer ──────────────────────────────────────────────────────────

class _DayCostFooter extends StatelessWidget {
  const _DayCostFooter({required this.items});
  final List<ItineraryItem> items;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> totals = {};
    for (final item in items) {
      if (item.plannedCost != null && item.plannedCost! > 0) {
        final c = item.currency ?? '?';
        totals[c] = (totals[c] ?? 0) + item.plannedCost!;
      }
    }
    if (totals.isEmpty) return const SizedBox.shrink();

    final parts = totals.entries.map((e) {
      final isWhole = e.value == e.value.truncateToDouble();
      final amt = isWhole ? e.value.toInt().toString() : e.value.toStringAsFixed(0);
      return '${e.key} $amt';
    }).join(' + ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 12, color: kColorInkSoft.withValues(alpha: 0.6)),
          const SizedBox(width: 5),
          Text(
            'Est. $parts',
            style: kStyleCaption.copyWith(fontSize: 11, color: kColorInkSoft),
          ),
        ],
      ),
    );
  }
}

// ─── Member presence row ──────────────────────────────────────────────────────

// Shows which members are present on a given day, based on their arrival/
// departure dates. Hidden when no member has dates set (avoid noise).
class _MemberPresenceRow extends ConsumerWidget {
  const _MemberPresenceRow({required this.date});
  final DateTime date;

  bool _isPresent(AppTripMember m) {
    final d = DateTime(date.year, date.month, date.day);
    if (m.arrivalDate != null) {
      final arr = DateTime(m.arrivalDate!.year, m.arrivalDate!.month, m.arrivalDate!.day);
      if (d.isBefore(arr)) return false;
    }
    if (m.departureDate != null) {
      final dep = DateTime(m.departureDate!.year, m.departureDate!.month, m.departureDate!.day);
      if (d.isAfter(dep)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(tripMembersProvider);
    // Only show when at least one member has travel dates configured.
    final anyHasDates = members.any((m) => m.hasDates);
    if (!anyHasDates) return const SizedBox.shrink();

    final present  = members.where(_isPresent).toList();
    final absent   = members.where((m) => !_isPresent(m)).toList();
    // If everyone is present, no need to show the row.
    if (absent.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
      child: Row(
        children: [
          const Icon(Icons.group_rounded, size: 12, color: kColorInkSoft),
          const SizedBox(width: kSpace2),
          ...present.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _TinyAvatar(name: m.profile.displayName, present: true),
            ),
          ),
          ...absent.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _TinyAvatar(name: m.profile.displayName, present: false),
            ),
          ),
          const SizedBox(width: kSpace2),
          Text(
            absent.length == 1
                ? '${absent.first.profile.displayName.split(' ').first} not here'
                : '${absent.length} members not here',
            style: kStyleCaption.copyWith(fontSize: 11, color: kColorInkSoft),
          ),
        ],
      ),
    );
  }
}

class _TinyAvatar extends StatelessWidget {
  const _TinyAvatar({required this.name, required this.present});
  final String name;
  final bool present;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: present ? kColorPrimarySoft : kColorSurfaceSunken,
        border: Border.all(
          color: present ? kColorPrimary.withValues(alpha: 0.3) : kColorBorder,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: present ? kColorPrimaryDark : kColorInkSoft,
          ),
        ),
      ),
    );
  }
}

// ─── Add item row ──────────────────────────────────────────────────────────────────────────────────────────────────────────

class _AddItemRow extends StatelessWidget {
  const _AddItemRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        child: Row(
          children: [
            const SizedBox(width: 50 + kSpace3), // align with content column
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: kColorBorder, width: 1.5),
              ),
            ),
            const SizedBox(width: kSpace3),
            Text(
              'Add item',
              style: kStyleCaption.copyWith(
                color: kColorInkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: kSpace1),
            const Icon(Icons.add_rounded, size: 14, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}
