import 'package:flutter/material.dart';
import '../data/date_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// The one tappable picker field (date, time, date range). Beige filled box
/// with a floating label, value or placeholder, and a trailing calendar/clock
/// icon that turns into a clear button once a value is set.
///
/// Use [WabwayDateField] / [WabwayTimeField] for the common single-value cases;
/// use this directly when the caller opens its own picker (e.g. a date range).
class WabwayPickerField extends StatelessWidget {
  const WabwayPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder = 'Not set',
    this.icon = Icons.calendar_today_outlined,
    this.onClear,
  });

  final String label;
  final String? value;
  final String placeholder;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Semantics(
      button: true,
      label: '$label: ${value ?? placeholder}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
            border: Border.all(color: kColorBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                      const SizedBox(height: 2),
                      Text(
                        value ?? placeholder,
                        style: hasValue
                            ? kStyleBodyMedium
                            : kStyleBody.copyWith(color: kColorInkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (hasValue && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: kColorInkSoft),
                    ),
                  )
                else
                  Icon(icon, size: 16, color: kColorInkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single date field that opens the Material date picker.
class WabwayDateField extends StatelessWidget {
  const WabwayDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Not set',
    this.firstDate,
    this.lastDate,
    this.initialPickerDate,
    this.clearable = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Where the picker opens when [value] is null (e.g. the trip start date).
  final DateTime? initialPickerDate;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 5);
    final last = lastDate ?? DateTime(now.year + 5);
    var initial = value ?? initialPickerDate ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => WabwayPickerField(
        label: label,
        value: value == null ? null : fmtDateLong(value!),
        placeholder: placeholder,
        onTap: () => _pick(context),
        onClear: clearable ? () => onChanged(null) : null,
      );
}

/// Single time field that opens the Material time picker.
class WabwayTimeField extends StatelessWidget {
  const WabwayTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Not set',
    this.clearable = true,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay?> onChanged;
  final String placeholder;
  final bool clearable;

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => WabwayPickerField(
        label: label,
        value: value == null ? null : fmtTimeOfDay(value!.hour, value!.minute),
        placeholder: placeholder,
        icon: Icons.schedule_rounded,
        onTap: () => _pick(context),
        onClear: clearable ? () => onChanged(null) : null,
      );
}
