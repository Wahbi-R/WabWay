import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwaySelectItem<T> {
  const WabwaySelectItem({required this.value, required this.label});
  final T value;
  final String label;
}

class WabwaySelectField<T> extends StatelessWidget {
  const WabwaySelectField({
    super.key,
    this.label,
    this.hint,
    required this.items,
    this.value,
    this.onChanged,
    this.validator,
    this.error,
  });

  final String? label;
  final String? hint;
  final List<WabwaySelectItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
          builder: (context, constraints) => FormField<T>(
            initialValue: value,
            validator: validator,
            builder: (state) => InputDecorator(
              decoration: kInputDecoration().copyWith(
                errorText: state.hasError ? state.errorText : error,
                errorStyle: kStyleOverline.copyWith(color: kColorDanger),
              ),
              isEmpty: state.value == null,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: state.value,
                  isExpanded: true,
                  menuWidth: constraints.maxWidth,
                  dropdownColor: kColorPaper,
                  borderRadius: kRadiusMd,
                  style: kStyleBody,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: kColorInkSoft,
                  ),
                  hint: hint != null
                      ? Text(hint!, style: kStyleBody.copyWith(color: kColorInkSoft))
                      : null,
                  onChanged: (v) {
                    state.didChange(v);
                    onChanged?.call(v);
                  },
                  items: items
                      .map((item) => DropdownMenuItem<T>(
                            value: item.value,
                            child: Text(item.label, style: kStyleBody),
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
