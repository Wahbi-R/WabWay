import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwaySelectItem<T> {
  const WabwaySelectItem({required this.value, required this.label});
  final T value;
  final String label;
}

class WabwaySelectField<T> extends StatefulWidget {
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
  State<WabwaySelectField<T>> createState() => _WabwaySelectFieldState<T>();
}

class _WabwaySelectFieldState<T> extends State<WabwaySelectField<T>> {
  final _fieldKey = GlobalKey<FormFieldState<T>>();

  @override
  void didUpdateWidget(WabwaySelectField<T> old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      // Sync the FormField's internal value when the parent changes it
      // (e.g. after a place-search auto-fill).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fieldKey.currentState?.didChange(widget.value);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(widget.label!, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(
          builder: (context, constraints) => FormField<T>(
            key: _fieldKey,
            initialValue: widget.value,
            validator: widget.validator,
            builder: (state) => InputDecorator(
              decoration: kInputDecoration().copyWith(
                errorText: state.hasError ? state.errorText : widget.error,
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
                  hint: widget.hint != null
                      ? Text(widget.hint!, style: kStyleBody.copyWith(color: kColorInkSoft))
                      : null,
                  onChanged: (v) {
                    state.didChange(v);
                    widget.onChanged?.call(v);
                  },
                  items: widget.items
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
