import 'package:flutter/material.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Show add item sheet / dialog ─────────────────────────────────────────────

Future<ItineraryItem?> showAddItemSheet(
  BuildContext context, {
  required String dayId,
  List<Spot> spots = const [],
  List<TripDocument> docs = const [],
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<ItineraryItem>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(ctx).height * 0.90,
          child: _AddItemContent(
            dayId: dayId,
            spots: spots,
            docs: docs,
            onSubmit: (item) => Navigator.pop(ctx, item),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<ItineraryItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddItemSheet(
      dayId: dayId,
      spots: spots,
      docs: docs,
      onSubmit: (item) => Navigator.pop(ctx, item),
    ),
  );
}

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.onSubmit,
  });
  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final ValueChanged<ItineraryItem> onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddItemContent(
          dayId: dayId,
          spots: spots,
          docs: docs,
          scrollController: ctrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

// ─── Form content ─────────────────────────────────────────────────────────────

class _AddItemContent extends StatefulWidget {
  const _AddItemContent({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final ValueChanged<ItineraryItem> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddItemContent> createState() => _AddItemContentState();
}

class _AddItemContentState extends State<_AddItemContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _mapsCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ItineraryItemType _type = ItineraryItemType.activity;
  TimeOfDay? _time;
  String? _linkedSpotId;
  final Set<String> _linkedDocIds = {};

  bool _showAdvanced = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _cityCtrl.dispose();
    _locationCtrl.dispose();
    _mapsCtrl.dispose();
    _confirmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final timeStr = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    widget.onSubmit(ItineraryItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dayId: widget.dayId,
      title: _titleCtrl.text.trim(),
      type: _type,
      time: timeStr,
      city: _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      mapsUrl: _mapsCtrl.text.trim().isEmpty ? null : _mapsCtrl.text.trim(),
      confirmationUrl: _confirmCtrl.text.trim().isEmpty ? null : _confirmCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      linkedSpotId: _linkedSpotId,
      linkedDocIds: _linkedDocIds.toList(),
    ));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text('Add itinerary item', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
                kSpace4, 0, kSpace4, kSpace6 + bottomPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Senso-ji Temple',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<ItineraryItemType>(
                    label: 'Type',
                    value: _type,
                    onChanged: (v) =>
                        setState(() => _type = v ?? ItineraryItemType.activity),
                    items: ItineraryItemType.values
                        .map((t) => WabwaySelectItem(value: t, label: t.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  // Time picker
                  _TimePicker(
                    selected: _time,
                    onTap: _pickTime,
                    onClear: () => setState(() => _time = null),
                  ),
                  const SizedBox(height: kSpace4),

                  Row(
                    children: [
                      Expanded(
                        child: WabwayTextField(
                          label: 'City',
                          hint: 'e.g. Tokyo',
                          controller: _cityCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Location / Address',
                    hint: 'e.g. 2-3-1 Asakusa, Taito City',
                    controller: _locationCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  // Linked spot
                  WabwaySelectField<String?>(
                    label: 'Linked spot (optional)',
                    value: _linkedSpotId,
                    onChanged: (v) => setState(() => _linkedSpotId = v),
                    items: [
                      const WabwaySelectItem(value: null, label: 'None'),
                      ...widget.spots.map(
                        (s) => WabwaySelectItem(
                            value: s.id, label: '${s.name} — ${s.city}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  // Linked documents
                  _DocsPicker(
                    docs: widget.docs,
                    selectedIds: _linkedDocIds,
                    onChanged: (id, checked) => setState(() {
                      if (checked) {
                        _linkedDocIds.add(id);
                      } else {
                        _linkedDocIds.remove(id);
                      }
                    }),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: kSpace3),

                  // Advanced fields toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: kColorInkSoft,
                        ),
                        const SizedBox(width: kSpace1),
                        Text(
                          'Advanced (links)',
                          style: kStyleCaptionMedium.copyWith(
                              color: kColorInkSoft),
                        ),
                      ],
                    ),
                  ),

                  if (_showAdvanced) ...[
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Google Maps URL',
                      hint: 'https://maps.google.com/…',
                      controller: _mapsCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Confirmation link',
                      hint: 'Booking reference URL',
                      controller: _confirmCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                  ],

                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add to itinerary',
                    icon: Icons.event_note_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Time picker row ──────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.selected,
    required this.onTap,
    required this.onClear,
  });

  final TimeOfDay? selected;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time (optional)',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: kSpace3),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: selected != null ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: selected != null ? kColorPrimary : kColorInkSoft,
                ),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    selected != null
                        ? '${selected!.hour.toString().padLeft(2, '0')}:${selected!.minute.toString().padLeft(2, '0')}'
                        : 'No time set — flexible item',
                    style: kStyleBody.copyWith(
                      color: selected != null ? kColorInk : kColorInkSoft,
                    ),
                  ),
                ),
                if (selected != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: kColorInkSoft),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: kColorInkSoft),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Document multi-picker ────────────────────────────────────────────────────

class _DocsPicker extends StatelessWidget {
  const _DocsPicker({
    required this.docs,
    required this.selectedIds,
    required this.onChanged,
  });
  final List<TripDocument> docs;
  final Set<String> selectedIds;
  final void Function(String id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attach documents (optional)',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        ...docs.map((d) {
          final checked = selectedIds.contains(d.id);
          return CheckboxListTile(
            value: checked,
            onChanged: (v) => onChanged(d.id, v ?? false),
            title: Text(d.title, style: kStyleBody),
            subtitle: Text(d.type.label, style: kStyleCaption),
            secondary: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: d.type.softColor,
                borderRadius: kRadiusMd,
              ),
              child: Icon(d.type.icon, size: 16, color: d.type.color),
            ),
            activeColor: kColorPrimary,
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }
}
