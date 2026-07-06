import 'package:flutter/material.dart';
import '../../core/places/listing_parser.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../data/accommodation_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'accommodations_screen.dart';

class AddAccommodationSheet extends StatefulWidget {
  const AddAccommodationSheet({
    super.key,
    required this.tripId,
    required this.userId,
    this.editing,
    this.prefilled,
    this.initialUrl,
  });

  final String tripId;
  final String userId;
  final Accommodation? editing;
  final ListingResult? prefilled;
  final String? initialUrl;

  @override
  State<AddAccommodationSheet> createState() => _AddAccommodationSheetState();
}

class _AddAccommodationSheetState extends State<AddAccommodationSheet> {
  int _step = 0;

  final _urlCtrl    = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();

  bool   _parsing   = false;
  bool   _saving    = false;
  bool   _deleting  = false;

  String _currency = 'USD';
  AccommodationStatus _status = AccommodationStatus.brainstorming;
  AccommodationSource? _source;
  DateTime? _checkIn;
  DateTime? _checkOut;
  String? _imageUrl;
  String? _parseError;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _step        = 1;
      _nameCtrl.text = e.name;
      _cityCtrl.text = e.city;
      _urlCtrl.text  = e.url ?? '';
      if (e.pricePerNight != null) {
        _priceCtrl.text = e.pricePerNight! % 1 == 0
            ? '${e.pricePerNight!.toInt()}'
            : e.pricePerNight!.toStringAsFixed(2);
      }
      _notesCtrl.text = e.notes ?? '';
      _currency   = e.currency;
      _status     = e.status;
      _source     = e.source;
      _checkIn    = e.checkIn;
      _checkOut   = e.checkOut;
      _imageUrl   = e.imageUrl;
    } else if (widget.prefilled != null) {
      _applyPrefilled(widget.prefilled!);
      if (widget.initialUrl != null) _urlCtrl.text = widget.initialUrl!;
      _step = 1;
    } else if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
    }
  }

  void _applyPrefilled(ListingResult r) {
    _nameCtrl.text = r.name;
    _cityCtrl.text = r.city ?? '';
    _imageUrl      = r.imageUrl;
    _source        = r.source;
    if (r.pricePerNight != null) {
      _priceCtrl.text = r.pricePerNight! % 1 == 0
          ? '${r.pricePerNight!.toInt()}'
          : r.pricePerNight!.toStringAsFixed(2);
    }
    if (r.currency != null) _currency = r.currency!;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _parsing = true; _parseError = null; });
    try {
      final result = await ListingParser.parse(url);
      if (!mounted) return;
      if (result != null) {
        _applyPrefilled(result);
        setState(() { _step = 1; _parsing = false; });
      } else {
        setState(() {
          _parsing    = false;
          _parseError = 'Could not parse that URL — please fill in manually.';
          _step       = 1;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _parsing    = false;
        _parseError = 'Could not reach that URL.';
        _step       = 1;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final price = double.tryParse(_priceCtrl.text.trim());
      final url   = _urlCtrl.text.trim();
      final city  = _cityCtrl.text.trim();
      final notes = _notesCtrl.text.trim();

      Accommodation result;
      if (widget.editing != null) {
        await AccommodationService.updateStatus(widget.editing!.id, _status);
        result = widget.editing!.copyWith(
          name:          name,
          url:           url.isEmpty ? null : url,
          city:          city,
          pricePerNight: price,
          currency:      _currency,
          checkIn:       _checkIn,
          checkOut:      _checkOut,
          status:        _status,
          source:        _source,
          notes:         notes.isEmpty ? null : notes,
          imageUrl:      _imageUrl,
        );
      } else {
        result = await AccommodationService.create(
          tripId:        widget.tripId,
          userId:        widget.userId,
          name:          name,
          city:          city,
          url:           url.isEmpty ? null : url,
          pricePerNight: price,
          currency:      _currency,
          checkIn:       _checkIn,
          checkOut:      _checkOut,
          status:        _status,
          source:        _source ?? (url.isNotEmpty ? AccommodationSource.fromUrl(url) : null),
          notes:         notes.isEmpty ? null : notes,
          imageUrl:      _imageUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, AccommodationSheetResult(accommodation: result));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save stay.', style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _delete() async {
    final id = widget.editing?.id;
    if (id == null) return;
    setState(() => _deleting = true);
    try {
      await AccommodationService.delete(id);
      if (!mounted) return;
      Navigator.pop(context, const AccommodationSheetResult(deleted: true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not delete stay.', style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final initial = isCheckIn
        ? (_checkIn ?? DateTime.now())
        : (_checkOut ?? _checkIn?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isCheckIn) {
        _checkIn = picked;
        if (_checkOut != null && _checkOut!.isBefore(picked)) {
          _checkOut = picked.add(const Duration(days: 1));
        }
      } else {
        _checkOut = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (context, scrollCtrl) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: kColorPaper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
                child: Row(
                  children: [
                    const WabwayDragHandle(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
                child: Row(
                  children: [
                    Text(
                      widget.editing != null ? 'Edit stay' : 'Add stay',
                      style: kStyleTitle,
                    ),
                    const Spacer(),
                    WabwayIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _step == 0 ? _buildStep0(scrollCtrl) : _buildStep1(scrollCtrl),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Step 0: URL input ──────────────────────────────────────────────────────

  Widget _buildStep0(ScrollController ctrl) {
    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: kSpace2),
          WabwayTextField(
            label: 'Paste a listing URL',
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _parseUrl(),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: kSpace2),
            Text(_parseError!, style: kStyleCaption.copyWith(color: kColorDanger)),
          ],
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Parse listing',
            icon: Icons.travel_explore_rounded,
            loading: _parsing,
            onPressed: _parsing ? null : _parseUrl,
            fullWidth: true,
          ),
          const SizedBox(height: kSpace3),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(
                'Add manually',
                style: kStyleBodyMedium.copyWith(color: kColorInkSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Form ────────────────────────────────────────────────────────────

  Widget _buildStep1(ScrollController ctrl) {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final isEditing = widget.editing != null;
    final detectedSrc = _source ??
        (_urlCtrl.text.trim().isNotEmpty
            ? AccommodationSource.fromUrl(_urlCtrl.text.trim())
            : null);

    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: kRadiusMd,
              child: Image.network(
                _imageUrl!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: kSpace4),
          ],

          WabwayTextField(
            label: 'Name',
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'City',
            controller: _cityCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: kSpace3),

          Row(
            children: [
              Expanded(
                child: WabwayTextField(
                  label: 'Price per night',
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: kSpace3),
              SizedBox(
                width: 100,
                child: _CurrencySelector(
                  value: _currency,
                  onChanged: (v) => setState(() => _currency = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),

          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Check-in',
                  date: _checkIn,
                  onTap: () => _pickDate(isCheckIn: true),
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: _DateField(
                  label: 'Check-out',
                  date: _checkOut,
                  onTap: () => _pickDate(isCheckIn: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),

          Text('Status', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            children: AccommodationStatus.values.map((s) {
              final sel = _status == s;
              return GestureDetector(
                onTap: () => setState(() => _status = s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? kColorPrimary : kColorSurfaceSunken,
                    borderRadius: kRadiusPill,
                    border: Border.all(color: sel ? kColorPrimary : kColorBorder),
                  ),
                  child: Text(
                    s.label,
                    style: kStyleCaption.copyWith(
                      color: sel ? Colors.white : kColorInk,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'Notes (optional)',
            controller: _notesCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'Listing URL',
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),

          if (detectedSrc != null && detectedSrc != AccommodationSource.other) ...[
            const SizedBox(height: kSpace3),
            Row(
              children: [
                Icon(detectedSrc.icon, size: 16, color: kColorInkSoft),
                const SizedBox(width: kSpace2),
                Text(detectedSrc.label,
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
              ],
            ),
          ],

          const SizedBox(height: kSpace5),

          WabwayButton(
            label: isEditing ? 'Update' : 'Save stay',
            loading: _saving,
            onPressed: _saving || _deleting ? null : _save,
            fullWidth: true,
            size: WabwayButtonSize.lg,
          ),

          if (isEditing) ...[
            const SizedBox(height: kSpace3),
            WabwayButton(
              label: 'Delete stay',
              variant: WabwayButtonVariant.ghost,
              loading: _deleting,
              onPressed: _saving || _deleting ? null : _delete,
              fullWidth: true,
              size: WabwayButtonSize.lg,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Currency selector ────────────────────────────────────────────────────────

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            style: kStyleBody.copyWith(color: kColorInk),
            dropdownColor: kColorPaper,
            borderRadius: kRadiusMd,
            items: _currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c, style: kStyleBody)))
                .toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    );
  }
}

// ─── Date field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.date, required this.onTap});

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  static String _fmt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 14),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: kStyleOverline),
                  const SizedBox(height: 2),
                  Text(
                    date != null ? _fmt(date!) : 'Pick date',
                    style: kStyleBody.copyWith(
                      color: date != null ? kColorInk : kColorInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_today_rounded, size: 16, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}
