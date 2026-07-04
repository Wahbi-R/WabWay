import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// ─── Dataset ──────────────────────────────────────────────────────────────────

// Popular travel destinations — countries first, then major cities.
const _kDestinations = <String>[
  // Countries
  'Australia', 'Austria', 'Belgium', 'Brazil', 'Cambodia', 'Canada', 'Chile',
  'China', 'Colombia', 'Croatia', 'Czech Republic', 'Denmark', 'Egypt',
  'Finland', 'France', 'Germany', 'Greece', 'Hungary', 'Iceland', 'India',
  'Indonesia', 'Ireland', 'Israel', 'Italy', 'Japan', 'Jordan', 'Kenya',
  'Laos', 'Malaysia', 'Mexico', 'Morocco', 'Myanmar', 'Nepal', 'Netherlands',
  'New Zealand', 'Norway', 'Peru', 'Philippines', 'Poland', 'Portugal',
  'Romania', 'Singapore', 'South Korea', 'Spain', 'Sri Lanka', 'Sweden',
  'Switzerland', 'Taiwan', 'Thailand', 'Turkey', 'United Arab Emirates',
  'United Kingdom', 'United States', 'Vietnam',

  // Major cities
  'Amsterdam, Netherlands', 'Athens, Greece', 'Bali, Indonesia',
  'Bangkok, Thailand', 'Barcelona, Spain', 'Beijing, China',
  'Berlin, Germany', 'Brussels, Belgium', 'Budapest, Hungary',
  'Buenos Aires, Argentina', 'Cairo, Egypt', 'Cape Town, South Africa',
  'Chiang Mai, Thailand', 'Copenhagen, Denmark', 'Dubai, UAE',
  'Dublin, Ireland', 'Edinburgh, UK', 'Florence, Italy',
  'Hanoi, Vietnam', 'Ho Chi Minh City, Vietnam', 'Hong Kong',
  'Istanbul, Turkey', 'Jakarta, Indonesia', 'Kyoto, Japan',
  'Lisbon, Portugal', 'London, UK', 'Los Angeles, USA',
  'Madrid, Spain', 'Marrakech, Morocco', 'Melbourne, Australia',
  'Mexico City, Mexico', 'Milan, Italy', 'Mumbai, India',
  'Munich, Germany', 'Nairobi, Kenya', 'New York, USA',
  'Oslo, Norway', 'Osaka, Japan', 'Paris, France',
  'Prague, Czech Republic', 'Reykjavik, Iceland', 'Rio de Janeiro, Brazil',
  'Rome, Italy', 'Sapporo, Japan', 'Seoul, South Korea',
  'Shanghai, China', 'Singapore', 'Stockholm, Sweden',
  'Sydney, Australia', 'Taipei, Taiwan', 'Tokyo, Japan',
  'Toronto, Canada', 'Vancouver, Canada', 'Venice, Italy',
  'Vienna, Austria', 'Warsaw, Poland', 'Zurich, Switzerland',
];

List<String> _suggestionsFor(String query) {
  if (query.trim().isEmpty) return const [];
  final q = query.trim().toLowerCase();
  return _kDestinations
      .where((d) => d.toLowerCase().contains(q))
      .take(6)
      .toList();
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class DestinationAutocomplete extends StatelessWidget {
  const DestinationAutocomplete({
    super.key,
    required this.controller,
    this.label = 'Destination',
    this.hint = 'e.g. Tokyo, Japan',
    this.textInputAction = TextInputAction.next,
    this.prefixIcon = Icons.place_outlined,
    this.onSelected,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction textInputAction;
  final IconData prefixIcon;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue value) =>
          _suggestionsFor(value.text),
      onSelected: (String selection) {
        controller.text = selection;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: selection.length),
        );
        onSelected?.call(selection);
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          textInputAction: textInputAction,
          style: kStyleBody,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
            labelStyle: kStyleCaption,
            prefixIcon: Icon(prefixIcon, size: 18, color: kColorInkSoft),
            filled: true,
            fillColor: kColorPaper,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: kSpace4, vertical: kSpace3),
            border: OutlineInputBorder(
              borderRadius: kRadiusMd,
              borderSide: const BorderSide(color: kColorBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: kRadiusMd,
              borderSide: const BorderSide(color: kColorBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: kRadiusMd,
              borderSide: BorderSide(color: kColorPrimary, width: 1.5),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: kRadiusMd,
            color: kColorPaper,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 220),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: kSpace1),
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: kSpace4),
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: kSpace4, vertical: kSpace3),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 16, color: kColorInkSoft),
                          const SizedBox(width: kSpace2),
                          Expanded(
                            child: Text(option, style: kStyleBody),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
