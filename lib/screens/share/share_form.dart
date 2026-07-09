import 'package:flutter/material.dart';
import '../../core/place_search_service.dart';
import '../../data/share_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Data collected by the form, passed to the [ShareForm.onSave] callback.
class ShareSaveData {
  const ShareSaveData({
    required this.title,
    required this.notes,
    this.location,
    this.category,
    this.docType,
    this.travelType,
    this.amount,
    this.date,
    this.mapsUrl,
    this.latitude,
    this.longitude,
    this.placeSource,
    this.planDayId,
    this.planItemType,
  });

  final String title;
  final String notes;
  final String? location;
  final String? category;
  final String? docType;
  final String? travelType;
  final double? amount;
  final DateTime? date;
  final String? mapsUrl;
  final double? latitude;
  final double? longitude;
  final String? placeSource;
  final String? planDayId;
  final String? planItemType;
}

class ShareForm extends StatefulWidget {
  const ShareForm({
    super.key,
    required this.share,
    required this.destination,
    required this.onSave,
    required this.onDiscard,
  });

  final IncomingShare? share;
  final ShareDestination destination;
  /// Called with the collected form data when the user taps Save.
  /// Throw to show an inline error; complete normally to dismiss.
  final Future<void> Function(ShareSaveData data) onSave;
  final VoidCallback onDiscard;

  @override
  State<ShareForm> createState() => _ShareFormState();
}

class _ShareFormState extends State<ShareForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _locationCtrl;

  String? _category;
  String? _docType;
  String? _travelType;
  DateTime? _date;
  bool _saving = false;
  String? _saveError;

  // Maps URL handling
  double? _parsedLat;
  double? _parsedLng;

  bool get _isMapsShare =>
      widget.share?.contentType == ShareContentType.googleMapsLink;

  @override
  void initState() {
    super.initState();
    _titleCtrl    = TextEditingController(text: widget.share?.detectedTitle ?? '');
    _notesCtrl    = TextEditingController();
    _amountCtrl   = TextEditingController();
    _locationCtrl = TextEditingController();

    if (_isMapsShare) {
      final rawContent = widget.share?.rawContent ?? '';
      final coords = PlaceSearchService.parseLatLng(rawContent);
      if (coords != null) {
        _parsedLat = coords.lat;
        _parsedLng = coords.lng;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _amountCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.share?.sharedAt ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _saving = true; _saveError = null; });
    try {
      await widget.onSave(ShareSaveData(
        title:       _titleCtrl.text.trim(),
        notes:       _notesCtrl.text.trim(),
        location:    _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        category:    _category,
        docType:     _docType,
        travelType:  _travelType,
        amount:      double.tryParse(_amountCtrl.text.trim()),
        date:        _date,
        mapsUrl:     _isMapsShare ? widget.share?.rawContent : null,
        latitude:    _parsedLat,
        longitude:   _parsedLng,
        placeSource: _parsedLat != null ? 'shared_maps_link' : null,
      ));
    } catch (e) {
      if (mounted) setState(() { _saving = false; _saveError = e.toString(); });
    }
  }

  String get _saveLabel => switch (widget.destination) {
        ShareDestination.spot => 'Save spot',
        ShareDestination.link => 'Save link',
        ShareDestination.travelItem => 'Save travel item',
        ShareDestination.document => 'Save document',
        ShareDestination.receipt => 'Save receipt',
        ShareDestination.planItem => 'Save plan item',
      };

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WabwayTextField(
            label: 'Title',
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Title is required' : null,
          ),
          const SizedBox(height: kSpace3),
          ..._buildDestinationFields(),
          const SizedBox(height: kSpace3),
          WabwayTextField(
            label: 'Notes (optional)',
            hint: 'Add any context for the group',
            controller: _notesCtrl,
            maxLines: 3,
          ),
          if (_saveError != null) ...[
            const SizedBox(height: kSpace3),
            Text(_saveError!, style: kStyleCaption.copyWith(color: kColorDanger)),
          ],
          const SizedBox(height: kSpace5),
          Row(
            children: [
              Expanded(
                child: WabwayButton(
                  label: 'Discard',
                  variant: WabwayButtonVariant.ghost,
                  onPressed: _saving ? null : widget.onDiscard,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                flex: 2,
                child: WabwayButton(
                  label: _saveLabel,
                  icon: Icons.check_rounded,
                  onPressed: _saving ? null : _submit,
                  loading: _saving,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDestinationFields() => switch (widget.destination) {
        ShareDestination.spot => _spotFields(),
        ShareDestination.link => _linkFields(),
        ShareDestination.travelItem => _travelItemFields(),
        ShareDestination.document => _documentFields(),
        ShareDestination.receipt => _receiptFields(),
        ShareDestination.planItem => [],
      };

  List<Widget> _spotFields() => [
        if (_isMapsShare) ...[
          _ReadOnlyField(
            label: 'Google Maps URL',
            value: widget.share?.rawContent ?? '',
            icon: Icons.map_rounded,
          ),
          if (_parsedLat != null) ...[
            const SizedBox(height: kSpace2),
            Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 13, color: kColorSuccess),
                const SizedBox(width: 4),
                Text(
                  'Map ready · ${_parsedLat!.toStringAsFixed(4)}, ${_parsedLng!.toStringAsFixed(4)}',
                  style: kStyleCaption.copyWith(color: kColorSuccess),
                ),
              ],
            ),
          ],
          const SizedBox(height: kSpace3),
          WabwayTextField(
            label: 'City (optional)',
            hint: 'e.g. Tokyo',
            controller: _locationCtrl,
            prefixIcon: Icons.place_rounded,
            textInputAction: TextInputAction.next,
          ),
        ] else
          WabwayTextField(
            label: 'Location or address',
            hint: 'e.g. Shinjuku, Tokyo',
            controller: _locationCtrl,
            prefixIcon: Icons.place_rounded,
            textInputAction: TextInputAction.next,
          ),
        const SizedBox(height: kSpace3),
        WabwaySelectField<String>(
          label: 'Category',
          hint: 'Pick a category',
          value: _category,
          onChanged: (v) => setState(() => _category = v),
          items: const [
            WabwaySelectItem(value: 'food', label: 'Food & drink'),
            WabwaySelectItem(value: 'attraction', label: 'Attraction'),
            WabwaySelectItem(value: 'shopping', label: 'Shopping'),
            WabwaySelectItem(value: 'accommodation', label: 'Accommodation'),
            WabwaySelectItem(value: 'transport', label: 'Transport hub'),
            WabwaySelectItem(value: 'other', label: 'Other'),
          ],
        ),
      ];

  List<Widget> _linkFields() => [
        _ReadOnlyField(
          label: 'URL',
          value: widget.share?.rawContent ?? '',
          icon: Icons.link_rounded,
        ),
      ];

  List<Widget> _travelItemFields() => [
        WabwaySelectField<String>(
          label: 'Type',
          hint: 'What kind of travel item?',
          value: _travelType,
          onChanged: (v) => setState(() => _travelType = v),
          items: const [
            WabwaySelectItem(value: 'flight', label: 'Flight'),
            WabwaySelectItem(value: 'hotel', label: 'Hotel'),
            WabwaySelectItem(value: 'train', label: 'Train'),
            WabwaySelectItem(value: 'ticket', label: 'Ticket or attraction'),
            WabwaySelectItem(value: 'reservation', label: 'Reservation'),
            WabwaySelectItem(value: 'other', label: 'Other'),
          ],
        ),
        const SizedBox(height: kSpace3),
        _DatePickerField(
          label: 'Date (optional)',
          value: _date,
          onTap: _pickDate,
        ),
      ];

  List<Widget> _documentFields() => [
        WabwaySelectField<String>(
          label: 'Document type',
          hint: 'What kind of document?',
          value: _docType,
          onChanged: (v) => setState(() => _docType = v),
          items: const [
            WabwaySelectItem(value: 'flight', label: 'Flight confirmation'),
            WabwaySelectItem(value: 'hotel', label: 'Hotel confirmation'),
            WabwaySelectItem(value: 'ticket', label: 'Ticket'),
            WabwaySelectItem(value: 'insurance', label: 'Insurance'),
            WabwaySelectItem(value: 'screenshot', label: 'Screenshot'),
            WabwaySelectItem(value: 'other', label: 'Other'),
          ],
        ),
      ];

  List<Widget> _receiptFields() => [
        WabwayTextField(
          label: 'Amount',
          hint: '¥0',
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: Icons.currency_yen_rounded,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: kSpace3),
        _DatePickerField(
          label: 'Date',
          value: _date,
          onTap: _pickDate,
        ),
      ];
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: 6),
        Container(
          height: kTapMin,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusSm,
            border: Border.all(color: kColorBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Expanded(
                child: Text(
                  value,
                  style: kStyleBody.copyWith(color: kColorInkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: kTapMin,
            padding: const EdgeInsets.symmetric(horizontal: kSpace3),
            decoration: BoxDecoration(
              color: kColorPaper,
              borderRadius: kRadiusSm,
              border: Border.all(color: kColorBorder),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: kColorInkSoft,
                ),
                const SizedBox(width: kSpace2),
                Text(
                  value != null ? _fmt(value!) : 'Pick a date',
                  style: kStyleBody.copyWith(
                    color: value != null ? kColorInk : kColorInkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
