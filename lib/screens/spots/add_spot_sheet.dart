import 'package:flutter/material.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<Spot?> showAddSpotSheet(BuildContext context) {
  final isDesktop =
      MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<Spot>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.85,
          child: _AddSpotContent(onSubmit: (spot) => Navigator.pop(dialogCtx, spot)),
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
      onSubmit: (spot) => Navigator.pop(ctx, spot),
    ),
  );
}

// ─── Mobile bottom sheet container ────────────────────────────────────────

class _AddSpotSheet extends StatelessWidget {
  const _AddSpotSheet({required this.onSubmit});
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
          scrollController: scrollCtrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

// ─── Shared form content ───────────────────────────────────────────────────

class _AddSpotContent extends StatefulWidget {
  const _AddSpotContent({
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<Spot> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddSpotContent> createState() => _AddSpotContentState();
}

class _AddSpotContentState extends State<_AddSpotContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _areaCtrl   = TextEditingController();
  final _mapsCtrl   = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  SpotCategory? _category;
  SpotStatus _status = SpotStatus.idea;

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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final spot = Spot(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      city: _cityCtrl.text.trim().isEmpty ? 'Unknown' : _cityCtrl.text.trim(),
      area: _areaCtrl.text.trim().isEmpty ? '' : _areaCtrl.text.trim(),
      category: _category ?? SpotCategory.landmark,
      status: _status,
      mapsUrl: _mapsCtrl.text.trim().isEmpty ? null : _mapsCtrl.text.trim(),
      sourceUrl: _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      addedBy: 'You',
    );
    widget.onSubmit(spot);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle (mobile only)
        if (widget.showDragHandle)
          Padding(
            padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace1),
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                color: kColorBorder,
                borderRadius: kRadiusPill,
              ),
            ),
          ),

        // Header
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

        // Form
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
                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add spot',
                    icon: Icons.add_rounded,
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
