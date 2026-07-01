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
        DropdownButtonFormField<T>(
          value: value,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          iconEnabledColor: kColorInkSoft,
          dropdownColor: kColorPaper,
          style: kStyleBody,
          hint: hint != null
              ? Text(hint!, style: kStyleBody.copyWith(color: kColorInkSoft))
              : null,
          decoration: kInputDecoration().copyWith(
            errorText: error,
            errorStyle: kStyleOverline.copyWith(color: kColorDanger),
          ),
          borderRadius: kRadiusMd,
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item.value,
                    child: Text(item.label, style: kStyleBody),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
