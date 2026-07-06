import 'package:flutter/material.dart';
import '../../core/places/nominatim_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class ExtractedSpotsScreen extends StatefulWidget {
  const ExtractedSpotsScreen({
    super.key,
    required this.places,
    required this.caption,
    required this.sourceUrl,
    required this.tripId,
    required this.userId,
    this.onDone,
  });

  final List<NominatimPlace> places;
  final String               caption;
  final String               sourceUrl;
  final String               tripId;
  final String               userId;
  final VoidCallback?        onDone;

  @override
  State<ExtractedSpotsScreen> createState() => _ExtractedSpotsScreenState();
}

class _ExtractedSpotsScreenState extends State<ExtractedSpotsScreen> {
  late final List<bool>          _selected;
  late final List<SpotCategory>  _categories;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected   = List.filled(widget.places.length, true);
    _categories = widget.places.map((p) => p.category).toList();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      int count = 0;
      for (int i = 0; i < widget.places.length; i++) {
        if (!_selected[i]) continue;
        final p = widget.places[i];
        await SpotService.createSpot(
          tripId:      widget.tripId,
          name:        p.name,
          city:        p.city.isNotEmpty ? p.city : p.country,
          area:        '',
          category:    _categories[i],
          status:      SpotStatus.wantToGo,
          addedBy:     widget.userId,
          sourceUrl:   widget.sourceUrl,
          latitude:    p.lat,
          longitude:   p.lon,
        );
        count++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Added $count spot${count == 1 ? '' : 's'}',
          style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
        ),
        backgroundColor: kColorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
        margin: const EdgeInsets.all(kSpace4),
      ));
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Places found', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Caption preview
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpace3),
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
                border: Border.all(color: kColorBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From caption',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  const SizedBox(height: kSpace1),
                  Text(
                    widget.caption,
                    style: kStyleCaption,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpace3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4),
            child: Text(
              'Found ${widget.places.length} place${widget.places.length == 1 ? '' : 's'}. '
              'Deselect any you don\'t want to add.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          const SizedBox(height: kSpace3),

          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4, vertical: kSpace2),
              itemCount: widget.places.length,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (_, i) => _SpotCard(
                place:    widget.places[i],
                selected: _selected[i],
                category: _categories[i],
                onToggle: (v) => setState(() => _selected[i] = v),
                onCategory: (c) => setState(() => _categories[i] = c),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: FilledButton(
                onPressed: selectedCount == 0 || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kColorPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Add $selectedCount spot${selectedCount == 1 ? '' : 's'}',
                        style: kStyleBodyMedium.copyWith(
                            color: kColorTextOnPrimary),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Spot card ─────────────────────────────────────────────────────────────────

class _SpotCard extends StatelessWidget {
  const _SpotCard({
    required this.place,
    required this.selected,
    required this.category,
    required this.onToggle,
    required this.onCategory,
  });

  final NominatimPlace    place;
  final bool              selected;
  final SpotCategory      category;
  final ValueChanged<bool>         onToggle;
  final ValueChanged<SpotCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusSm,
                  ),
                  child: Icon(category.icon, size: 18, color: kColorPrimary),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: kStyleBodySemibold,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        [place.city, place.country]
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: kColorPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            // Category picker
            Wrap(
              spacing: kSpace2,
              children: SpotCategory.values.map((c) {
                final active = c == category;
                return GestureDetector(
                  onTap: () => onCategory(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace2, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? kColorPrimary : kColorSurfaceSunken,
                      borderRadius: kRadiusSm,
                      border: Border.all(
                        color: active ? kColorPrimary : kColorBorder,
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: kStyleCaption.copyWith(
                        color: active ? kColorTextOnPrimary : kColorInk,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
