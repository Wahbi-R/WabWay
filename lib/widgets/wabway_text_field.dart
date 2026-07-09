import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwayTextField extends StatelessWidget {
  const WabwayTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.error,
    this.helpText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.focusNode,
    this.inputFormatters,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final String? error;
  final String? helpText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autofocus;
  final int maxLines;
  final bool enabled;
  final bool readOnly;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

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
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
          textInputAction: textInputAction,
          obscureText: obscureText,
          autofocus: autofocus,
          maxLines: maxLines,
          enabled: enabled,
          readOnly: readOnly,
          focusNode: focusNode,
          inputFormatters: inputFormatters,
          style: kStyleBody,
          decoration: kInputDecoration(
            hint: hint,
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(prefixIcon, size: 18, color: kColorInkSoft),
                  )
                : null,
            suffix: suffixIcon != null
                ? Icon(suffixIcon, size: 18, color: kColorInkSoft)
                : null,
          ).copyWith(
            errorText: error,
            helperText: helpText,
            helperStyle: kStyleOverline.copyWith(color: kColorInkSoft),
            errorStyle: kStyleOverline.copyWith(color: kColorDanger),
            fillColor: enabled ? kColorPaper : kColorSurfaceSunken,
          ),
        ),
      ],
    );
  }
}
