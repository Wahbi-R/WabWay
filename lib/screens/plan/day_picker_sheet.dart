import 'package:flutter/material.dart';
import '../../data/plan_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<(String dayId, TimeOfDay? time)?> showDayPickerSheet(
  BuildContext context, {
  required List<TripDay> days,
}) {
  return showModalBottomSheet<(String, TimeOfDay?)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DayPickerSheet(days: days),
  );
}

class _DayPickerSheet extends StatefulWidget {
  const _DayPickerSheet({required this.days});
  final List<TripDay> days;

  @override
  State<_DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<_DayPickerSheet> {
  String? _selectedDayId;
  TimeOfDay? _time;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WabwayDragHandle(),
                  const SizedBox(height: kSpace3),
                  Text('Add to which day?', style: kStyleTitle),
                  const SizedBox(height: kSpace2),
                  Text('Pick a day for this spot.',
                      style: kStyleBody.copyWith(color: kColorInkSoft)),
                  const SizedBox(height: kSpace3),
                  const Divider(height: 1, color: kColorBorder),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace3),
                itemCount: widget.days.length,
                separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
                itemBuilder: (_, i) {
                  final day = widget.days[i];
                  final selected = _selectedDayId == day.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayId = day.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(kSpace3),
                      decoration: BoxDecoration(
                        color:
                            selected ? kColorPrimarySoft : kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(
                          color: selected ? kColorPrimary : kColorBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected ? kColorPrimary : kColorBorder,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.dayNumber}',
                                style: kStyleCaptionMedium.copyWith(
                                  color: selected
                                      ? kColorTextOnPrimary
                                      : kColorInkSoft,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpace3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(day.city, style: kStyleBodyMedium),
                                Text(fmtDate(day.date),
                                    style: kStyleCaption.copyWith(
                                        color: kColorInkSoft)),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: kColorPrimary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  kSpace4, 0, kSpace4,
                  kSpace4 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: kSpace3),
                      decoration: BoxDecoration(
                        color: kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 16, color: kColorInkSoft),
                          const SizedBox(width: kSpace2),
                          Text(
                            _time != null
                                ? _time!.format(context)
                                : 'Set time (optional)',
                            style: kStyleBody.copyWith(
                              color:
                                  _time != null ? kColorInk : kColorInkSoft,
                            ),
                          ),
                          if (_time != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _time = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: kColorInkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  WabwayButton(
                    label: 'Add to plan',
                    icon: Icons.add_rounded,
                    fullWidth: true,
                    onPressed: _selectedDayId == null
                        ? null
                        : () => Navigator.pop(
                            context, (_selectedDayId!, _time)),
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
