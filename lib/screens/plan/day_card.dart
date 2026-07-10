import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    this.onReorder,
    this.onToggleDone,
  });

  final TripDay day;
  final String? selectedItemId;
  final ValueChanged<String> onItemTap;
  final VoidCallback onAddItem;
  final bool isDesktop;
  final VoidCallback? onDayTap;
  final bool daySelected;
  final VoidCallback? onEditDay;
  final ValueChanged<List<ItineraryItem>>? onReorder;
  // Called with an item id when the user taps the timeline dot to check/uncheck.
  final ValueChanged<String>? onToggleDone;

  @override
  State<TripDayCard> createState() => _TripDayCardState();
}

class _TripDayCardState extends State<TripDayCard> {
  bool _notesExpanded = false;

  void _handleHeaderTap() {
    if (widget.isDesktop) {
      widget.onDayTap?.call();
    } else {
      setState(() => _notesExpanded = !_notesExpanded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.day.sortedItems;
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
            onTap: headerTappable ? _handleHeaderTap : null,
            onEdit: widget.onEditDay,
          ),
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
                _AddItemRow(onTap: widget.onAddItem),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.expanded,
    required this.hasNotes,
    required this.isDesktop,
    required this.selected,
    this.onTap,
    this.onEdit,
  });

  final TripDay day;
  final bool expanded;
  final bool hasNotes;
  final bool isDesktop;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

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
                        Text(
                          fmtDayDate(day.date),
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: kTextSm,
                            fontWeight: FontWeight.w500,
                            color: kColorInkSoft,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.location_city_rounded,
                            size: 11, color: kColorInkSoft),
                        const SizedBox(width: 3),
                        Text(
                          day.city,
                          style: kStyleCaption.copyWith(fontSize: 12),
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
                  ],
                ),
              ),

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
              if (onEdit != null) ...[
                const SizedBox(width: kSpace2),
                GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 16, color: kColorInkSoft),
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
        _AddItemRow(onTap: widget.onAddItem),
      ],
    );
  }
}

// ─── Add item row ─────────────────────────────────────────────────────────────

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
