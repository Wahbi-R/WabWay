import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/plan_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'plan/day_card.dart';
import 'plan/item_detail.dart';
import 'plan/add_item_sheet.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final List<TripDay> _days = List.from(kMockTripDays);
  String? _selectedItemId;
  String? _selectedDayId;

  ItineraryItem? get _selectedItem => itemById(_days, _selectedItemId ?? '');
  TripDay? get _selectedDay => _selectedItem == null
      ? null
      : dayForItem(_days, _selectedItemId ?? '');

  void _selectItem(String id) =>
      setState(() { _selectedItemId = id; _selectedDayId = null; });

  void _selectDay(String id) =>
      setState(() { _selectedDayId = id; _selectedItemId = null; });

  void _deleteItem(String itemId) {
    setState(() {
      for (final day in _days) {
        day.items.removeWhere((i) => i.id == itemId);
      }
      if (_selectedItemId == itemId) _selectedItemId = null;
    });
  }

  Future<void> _addItem(BuildContext context, String dayId) async {
    final item = await showAddItemSheet(context, dayId: dayId);
    if (item != null && mounted) {
      setState(() {
        final day = _days.where((d) => d.id == dayId).firstOrNull;
        day?.items.add(item);
        _selectedItemId = item.id;
      });
    }
  }

  Future<void> _addDay(BuildContext context) async {
    final day = await _showAddDayDialog(context);
    if (day != null && mounted) {
      setState(() {
        final newDay = TripDay(
          id: day.id,
          dayNumber: _days.length + 1,
          date: day.date,
          city: day.city,
          notes: day.notes,
        );
        _days.add(newDay);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // ─── Desktop ────────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopPlanBar(
            dayCount: _days.length,
            onAddDay: () => _addDay(context),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: scrollable timeline
                SizedBox(
                  width: 420,
                  child: _days.isEmpty
                      ? _buildEmptyTimeline(context)
                      : ListView.separated(
                          padding: const EdgeInsets.all(kSpace4),
                          itemCount: _days.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: kSpace3),
                          itemBuilder: (ctx, i) => TripDayCard(
                            day: _days[i],
                            selectedItemId: _selectedItemId,
                            onItemTap: _selectItem,
                            onAddItem: () => _addItem(context, _days[i].id),
                            isDesktop: true,
                            onDayTap: () => _selectDay(_days[i].id),
                            daySelected: _selectedDayId == _days[i].id,
                          ),
                        ),
                ),
                const VerticalDivider(
                    width: 1, thickness: 1, color: kColorBorder),

                // Right: detail panel
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
    final day = _selectedDay;

    if (item != null && day != null) {
      return SingleChildScrollView(
        child: ItemDetailContent(
          key: ValueKey(item.id),
          item: item,
          day: day,
          onDelete: () => _deleteItem(item.id),
        ),
      );
    }

    if (_selectedDayId != null) {
      final selectedDay =
          _days.where((d) => d.id == _selectedDayId).firstOrNull;
      if (selectedDay != null) {
        return SingleChildScrollView(
          child: _DayDetailPanel(
            key: ValueKey(selectedDay.id),
            day: selectedDay,
            onAddItem: () => _addItem(context, selectedDay.id),
          ),
        );
      }
    }

    return const Center(
      child: WabwayEmptyState(
        icon: Icons.event_note_rounded,
        title: 'Select an item',
        description:
            'Click a day header to see its details, or tap an item for more info.',
      ),
    );
  }

  Widget _buildEmptyTimeline(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WabwayEmptyState(
            icon: Icons.calendar_today_rounded,
            title: 'No days yet',
            description: 'Add your first trip day to get started.',
          ),
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Add Day',
            icon: Icons.add_rounded,
            onPressed: () => _addDay(context),
          ),
        ],
      ),
    );
  }

  // ─── Mobile ──────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Plan', style: kStyleTitle),
        actions: [
          TextButton.icon(
            onPressed: () => _addDay(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Day', style: kStyleCaptionMedium),
            style: TextButton.styleFrom(foregroundColor: kColorInkSoft),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: _days.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WabwayEmptyState(
                    icon: Icons.calendar_today_rounded,
                    title: 'No days yet',
                    description: 'Add your first trip day to start planning.',
                  ),
                  const SizedBox(height: kSpace4),
                  WabwayButton(
                    label: 'Add Day',
                    icon: Icons.add_rounded,
                    onPressed: () => _addDay(context),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(kSpace4),
              itemCount: _days.length,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (ctx, i) => TripDayCard(
                day: _days[i],
                onItemTap: (id) {
                  final item = itemById(_days, id);
                  final day = dayForItem(_days, id);
                  if (item != null && day != null) {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          item: item,
                          day: day,
                          onDelete: () => _deleteItem(id),
                        ),
                      ),
                    );
                  }
                },
                onAddItem: () => _addItem(context, _days[i].id),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plan_fab',
        onPressed: () {
          if (_days.isEmpty) {
            _addDay(context);
          } else {
            _addItem(context, _days.last.id);
          }
        },
        icon: const Icon(Icons.event_note_rounded),
        label: Text(
          'Add item',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }
}

// ─── Desktop day detail panel ────────────────────────────────────────────────

class _DayDetailPanel extends StatelessWidget {
  const _DayDetailPanel({
    super.key,
    required this.day,
    required this.onAddItem,
  });

  final TripDay day;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final itemsByType = <ItineraryItemType, int>{};
    for (final item in day.items) {
      itemsByType[item.type] = (itemsByType[item.type] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace5),
          color: kColorPrimarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: kColorPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.dayNumber}',
                        style: kStyleBodySemibold.copyWith(
                          color: kColorTextOnPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${day.dayNumber}',
                          style: kStyleTitle.copyWith(fontSize: 20)),
                      Text(
                        fmtDayDate(day.date),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: kTextSm,
                          color: kColorInkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: kSpace3),
              Row(
                children: [
                  const Icon(Icons.location_city_rounded,
                      size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Text(day.city,
                      style: kStyleBodyMedium.copyWith(color: kColorInk)),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(kSpace5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notes
              if (day.notes != null && day.notes!.isNotEmpty) ...[
                Text('Notes', style: kStyleCaptionMedium.copyWith(color: kColorInkSoft)),
                const SizedBox(height: kSpace2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kSpace3),
                  decoration: BoxDecoration(
                    color: kColorSurfaceSunken,
                    borderRadius: kRadiusMd,
                    border: Border.all(color: kColorBorder),
                  ),
                  child: Text(
                    day.notes!,
                    style: kStyleBody.copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: kSpace5),
              ],

              // Item summary
              if (day.items.isNotEmpty) ...[
                Text('${day.items.length} item${day.items.length == 1 ? '' : 's'}',
                    style: kStyleCaptionMedium.copyWith(color: kColorInkSoft)),
                const SizedBox(height: kSpace2),
                Wrap(
                  spacing: kSpace2,
                  runSpacing: kSpace2,
                  children: [
                    for (final entry in itemsByType.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: entry.key.softColor,
                          borderRadius: kRadiusPill,
                          border: Border.all(
                              color: entry.key.color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.key.icon,
                                size: 12, color: entry.key.color),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.value} ${entry.key.label}',
                              style: kStyleCaption.copyWith(
                                color: entry.key.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: kSpace5),
              ],

              WabwayButton(
                label: 'Add item to this day',
                icon: Icons.add_rounded,
                variant: WabwayButtonVariant.ghost,
                onPressed: onAddItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopPlanBar extends StatelessWidget {
  const _DesktopPlanBar({
    required this.dayCount,
    required this.onAddDay,
  });

  final int dayCount;
  final VoidCallback onAddDay;

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
          Text('Plan', style: kStyleTitle),
          const SizedBox(width: kSpace3),
          if (dayCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusPill,
              ),
              child: Text(
                '$dayCount days',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kColorInkSoft,
                ),
              ),
            ),
          const Spacer(),
          WabwayButton(
            label: 'Add Day',
            icon: Icons.calendar_today_rounded,
            size: WabwayButtonSize.sm,
            variant: WabwayButtonVariant.ghost,
            onPressed: onAddDay,
          ),
        ],
      ),
    );
  }
}

// ─── Add day dialog ───────────────────────────────────────────────────────────

Future<TripDay?> _showAddDayDialog(BuildContext context) {
  return showDialog<TripDay>(
    context: context,
    builder: (ctx) => const _AddDayDialog(),
  );
}

class _AddDayDialog extends StatefulWidget {
  const _AddDayDialog();

  @override
  State<_AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<_AddDayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      TripDay(
        id: 'day_${DateTime.now().millisecondsSinceEpoch}',
        dayNumber: 0,
        date: _date,
        city: _cityCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Add day', style: kStyleBodySemibold),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace2),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: kSpace3),
                  decoration: BoxDecoration(
                    color: kColorSurfaceSunken,
                    borderRadius: kRadiusMd,
                    border: Border.all(color: kColorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: kColorInkSoft),
                      const SizedBox(width: kSpace2),
                      Text(
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                        style: kStyleBody,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: kSpace3),
              WabwayTextField(
                label: 'City',
                hint: 'e.g. Tokyo',
                controller: _cityCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'City is required'
                    : null,
              ),
              const SizedBox(height: kSpace3),
              WabwayTextField(
                label: 'Notes (optional)',
                hint: 'Any notes for this day',
                controller: _notesCtrl,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Add day',
              style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
        ),
      ],
    );
  }
}
