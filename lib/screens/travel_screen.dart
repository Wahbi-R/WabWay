import 'package:flutter/material.dart';
import '../data/travel_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'travel/travel_item_card.dart';
import 'travel/travel_item_detail.dart';
import 'travel/add_travel_sheet.dart';

class TravelScreen extends StatefulWidget {
  const TravelScreen({super.key});

  @override
  State<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends State<TravelScreen> {
  final List<TravelItem> _items = List.from(kMockTravelItems);
  TravelItemType? _filter; // null = All
  String? _selectedId;

  TravelItem? get _selectedItem =>
      _selectedId == null ? null : _items.where((i) => i.id == _selectedId).firstOrNull;

  List<TravelItem> get _filtered =>
      _filter == null ? _items : _items.where((i) => i.type == _filter).toList();

  void _select(String id) => setState(() => _selectedId = id);

  void _delete(String id) {
    setState(() {
      _items.removeWhere((i) => i.id == id);
      if (_selectedId == id) _selectedId = null;
    });
  }

  Future<void> _addItem(BuildContext context) async {
    final item = await showAddTravelSheet(context);
    if (item != null && mounted) {
      setState(() {
        _items.add(item);
        _selectedId = item.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // ─── Desktop ──────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopTravelBar(
            itemCount: _items.length,
            onAdd: () => _addItem(context),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      _FilterChips(
                        selected: _filter,
                        onSelect: (t) => setState(() {
                          _filter = _filter == t ? null : t;
                          _selectedId = null;
                        }),
                      ),
                      Expanded(child: _buildList(desktop: true)),
                    ],
                  ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: kColorBorder),
                Expanded(child: _buildDesktopDetail()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetail() {
    final item = _selectedItem;
    if (item != null) {
      return SingleChildScrollView(
        child: TravelItemDetailContent(
          key: ValueKey(item.id),
          item: item,
          onDelete: () => _delete(item.id),
        ),
      );
    }
    return const Center(
      child: WabwayEmptyState(
        icon: Icons.flight_rounded,
        title: 'Select a travel item',
        description: 'Pick a flight, hotel, or booking from the list to see details.',
      ),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Travel', style: kStyleTitle),
      ),
      body: Column(
        children: [
          _FilterChips(
            selected: _filter,
            onSelect: (t) => setState(() => _filter = _filter == t ? null : t),
          ),
          Expanded(child: _buildList(desktop: false)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'travel_fab',
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add travel',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }

  // ─── Shared list ──────────────────────────────────────────────────────────

  Widget _buildList({required bool desktop}) {
    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: _filter == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WabwayEmptyState(
                    icon: Icons.flight_rounded,
                    title: 'No travel items yet',
                    description:
                        'Add flights, hotels, trains, tickets, and reservations here.',
                  ),
                  if (!desktop) ...[
                    const SizedBox(height: kSpace4),
                    WabwayButton(
                      label: 'Add travel item',
                      icon: Icons.add_rounded,
                      onPressed: () => _addItem(context),
                    ),
                  ],
                ],
              )
            : WabwayEmptyState(
                icon: _filter!.icon,
                title: 'No ${_filter!.label.toLowerCase()}s',
                description: 'No ${_filter!.label.toLowerCase()} items added yet.',
              ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        kSpace4,
        kSpace3,
        kSpace4,
        desktop ? kSpace4 : kSpace20,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
      itemBuilder: (ctx, i) {
        final item = items[i];
        return TravelItemCard(
          item: item,
          isSelected: desktop && _selectedId == item.id,
          onTap: desktop
              ? () => _select(item.id)
              : () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => TravelItemDetailScreen(
                        item: item,
                        onDelete: () => _delete(item.id),
                      ),
                    ),
                  ),
        );
      },
    );
  }
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopTravelBar extends StatelessWidget {
  const _DesktopTravelBar({
    required this.itemCount,
    required this.onAdd,
  });

  final int itemCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Row(
        children: [
          Text('Travel', style: kStyleTitle),
          const SizedBox(width: kSpace3),
          if (itemCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusPill,
              ),
              child: Text(
                '$itemCount items',
                style: kStyleCaption.copyWith(
                  color: kColorInkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Spacer(),
          WabwayButton(
            label: 'Add item',
            icon: Icons.add_rounded,
            size: WabwayButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelect,
  });

  final TravelItemType? selected;
  final ValueChanged<TravelItemType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
        children: TravelItemType.values.map((type) {
          final isActive = selected == type;
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: _FilterChip(
              type: type,
              isActive: isActive,
              onTap: () => onSelect(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.type,
    required this.isActive,
    required this.onTap,
  });
  final TravelItemType type;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.type.color;
    final softColor = widget.type.softColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive ? color : _hovered ? softColor : kColorPaper,
            borderRadius: kRadiusPill,
            border: Border.all(
              color: widget.isActive ? color : kColorBorder,
              width: widget.isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.type.icon,
                size: 14,
                color: widget.isActive ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                widget.type.label,
                style: kStyleCaption.copyWith(
                  color: widget.isActive ? Colors.white : kColorInk,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
