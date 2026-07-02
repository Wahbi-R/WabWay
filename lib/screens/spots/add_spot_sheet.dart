import 'package:flutter/material.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<Spot?> showAddSpotSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<Spot>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.85,
          child: _AddSpotContent(
            tripId: tripId,
            userId: userId,
            onSubmit: (spot) => Navigator.pop(dialogCtx, spot),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<Spot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddSpotSheet(
      tripId: tripId,
      userId: userId,
      onSubmit: (spot) => Navigator.pop(ctx, spot),
    ),
  );
}

// ─── Mobile bottom sheet container ────────────────────────────────────────────

class _AddSpotSheet extends StatelessWidget {
  const _AddSpotSheet({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
  });
  final String tripId;
  final String userId;
  final ValueChanged<Spot> onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddSpotContent(
          tripId: tripId,
          userId: userId,
          scrollController: scrollCtrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

// ─── Shared form content ──────────────────────────────────────────────────────

class _AddSpotContent extends StatefulWidget {
  const _AddSpotContent({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final String tripId;
  final String userId;
  final ValueChanged<Spot> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddSpotContent> createState() => _AddSpotContentState();
}

class _AddSpotContentState extends State<_AddSpotContent> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _areaCtrl   = TextEditingController();
  final _mapsCtrl   = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  SpotCategory? _category;
  SpotStatus _status = SpotStatus.idea;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _mapsCtrl.dispose();
    _sourceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final spot = await SpotService.createSpot(
        tripId:    widget.tripId,
        name:      _nameCtrl.text.trim(),
        city:      _cityCtrl.text.trim(),
        area:      _areaCtrl.text.trim(),
        category:  _category ?? SpotCategory.landmark,
        status:    _status,
        addedBy:   widget.userId,
        sourceUrl: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
        mapsUrl:   _mapsCtrl.text.trim().isEmpty   ? null : _mapsCtrl.text.trim(),
        notes:     _notesCtrl.text.trim().isEmpty   ? null : _notesCtrl.text.trim(),
      );
      widget.onSubmit(spot);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
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
              Text('Add a spot', style: kStyleTitle),
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
              kSpace4,
              0,
              kSpace4,
              kSpace6 + bottomPad,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayTextField(
                    label: 'Name',
                    hint: 'e.g. Senso-ji Temple',
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  Row(
                    children: [
                      Expanded(
                        child: WabwayTextField(
                          label: 'City',
                          hint: 'Tokyo',
                          controller: _cityCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: WabwayTextField(
                          label: 'Area',
                          hint: 'Asakusa',
                          controller: _areaCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<SpotCategory>(
                    label: 'Category',
                    hint: 'Pick a category',
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                    items: SpotCategory.values
                        .map((c) => WabwaySelectItem(value: c, label: c.label))
                        .toList(),
                    validator: (v) => v == null ? 'Pick a category' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<SpotStatus>(
                    label: 'Status',
                    value: _status,
                    onChanged: (v) => setState(() => _status = v ?? SpotStatus.idea),
                    items: SpotStatus.values
                        .map((s) => WabwaySelectItem(value: s, label: s.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Google Maps URL',
                    hint: 'https://maps.google.com/…',
                    controller: _mapsCtrl,
                    prefixIcon: Icons.map_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Source URL',
                    hint: 'Instagram, TikTok, article link…',
                    controller: _sourceCtrl,
                    prefixIcon: Icons.link_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Tips, context, opening hours…',
                    controller: _notesCtrl,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: kSpace3),
                    Text(
                      _error!,
                      style: kStyleCaption.copyWith(color: kColorDanger),
                    ),
                  ],

                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add spot',
                    icon: Icons.add_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
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
