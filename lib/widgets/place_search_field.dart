import 'package:flutter/material.dart';
import '../core/place_search_service.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'wabway_text_field.dart';

/// A text field that searches for places on submit (Enter key or search icon tap).
/// Uses the wabway-server Google Places endpoint if available, with a Photon
/// (OSM) fallback.
///
/// [label] is shown as the floating label. [hint] is the placeholder text.
/// [onSelected] is called when the user picks a result from the dropdown.
/// [limit] controls the maximum number of results returned.
/// [locationBias] is a destination name (e.g. "Japan") that gets appended to
/// queries that don't already include a location, so results are geo-relevant.
class PlaceSearchField extends StatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.onSelected,
    this.label = 'Search places',
    this.hint = 'e.g. Hinoya Curry Tokyo',
    this.controller,
    this.latitude,
    this.longitude,
    this.limit = 6,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
    this.locationBias,
  });

  final ValueChanged<PlaceSuggestion> onSelected;
  final String label;
  final String hint;
  final TextEditingController? controller;
  final double? latitude;
  final double? longitude;
  final int limit;
  final bool autofocus;
  final TextInputAction textInputAction;
  /// Trip destination name used as a location hint (e.g. "Japan").
  /// Automatically appended to the search query when the user hasn't typed
  /// a location word already. Shown in the helper text below the field.
  final String? locationBias;

  @override
  State<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends State<PlaceSearchField> {
  late final TextEditingController _ctrl;
  bool _ownsController = false;

  List<PlaceSuggestion> _results = [];
  bool _showResults = false;
  bool _loading = false;
  // Prevents _onFocusChange from hiding results when a search was just triggered.
  // Set synchronously at the start of _search() so it's true before the
  // focus-loss event fires (keyboard closes on mobile).
  bool _suppressHide = false;

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController();
      _ownsController = true;
    }
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    if (_ownsController) _ctrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && !_loading && !_suppressHide) {
      setState(() => _showResults = false);
    }
  }

  /// Returns true when [query] already contains a location word from [bias],
  /// so we don't double-append the destination.
  bool _queryHasBias(String query, String bias) {
    final words = bias.toLowerCase().split(RegExp(r'[\s,&/]+'))
        .where((w) => w.length > 2);
    final q = query.toLowerCase();
    return words.any(q.contains);
  }

  Future<void> _search() async {
    final userQuery = _ctrl.text.trim();
    if (userQuery.isEmpty) return;
    _suppressHide = true;

    // Append the trip destination when it adds location context the user
    // hasn't already provided — keeps results geo-relevant without changing
    // what appears in the text field.
    final bias = widget.locationBias;
    final effectiveQuery = (bias != null && bias.isNotEmpty &&
            !_queryHasBias(userQuery, bias))
        ? '$userQuery $bias'
        : userQuery;

    setState(() { _loading = true; _results = []; _showResults = true; });
    final results = await PlaceSearchService.search(
      effectiveQuery,
      latitude: widget.latitude,
      longitude: widget.longitude,
      limit: widget.limit,
    );
    if (!mounted) return;
    _suppressHide = false;
    setState(() { _results = results; _loading = false; _showResults = true; });
  }

  void _select(PlaceSuggestion place) {
    _ctrl.text = place.name;
    _focus.unfocus();
    setState(() { _results = []; _showResults = false; _loading = false; });
    widget.onSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WabwayTextField(
          label: widget.label,
          hint: widget.hint,
          controller: _ctrl,
          focusNode: _focus,
          autofocus: widget.autofocus,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: (_) => _search(),
          suffixIcon: _loading
              ? Icons.hourglass_top_rounded
              : Icons.search_rounded,
          onSuffixTap: _search,
          helpText: widget.locationBias != null && widget.locationBias!.isNotEmpty
              ? 'Tap 🔍 or press Search  ·  Searching in ${widget.locationBias}'
              : 'Tap 🔍 or press Search  ·  Add a trip destination for local results',
        ),
        if (_showResults)
          _ResultsDropdown(
            results: _results,
            loading: _loading,
            onSelected: _select,
          ),
      ],
    );
  }
}

class _ResultsDropdown extends StatelessWidget {
  const _ResultsDropdown({
    required this.results,
    required this.loading,
    required this.onSelected,
  });

  final List<PlaceSuggestion> results;
  final bool loading;
  final ValueChanged<PlaceSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.all(kSpace4),
              child: Center(child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))),
            )
          : results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace4, vertical: kSpace3),
                  child: Text('No results found',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                )
              : Column(
                  children: results.map((p) => _ResultTile(
                    suggestion: p,
                    onTap: () => onSelected(p),
                  )).toList(),
                ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.suggestion, required this.onTap});
  final PlaceSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (suggestion.address.isNotEmpty) suggestion.address,
      if (suggestion.city.isNotEmpty) suggestion.city,
      if (suggestion.country.isNotEmpty) suggestion.country,
    ].join(', ');

    return InkWell(
      onTap: onTap,
      borderRadius: kRadiusMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, size: 16, color: kColorInkSoft),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(suggestion.name, style: kStyleBodyMedium),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
