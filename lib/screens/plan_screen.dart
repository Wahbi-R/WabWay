import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  static const _days = [
    ('Day 1', 'Nov 12', ['Arrive at Narita', 'Check in — Shinjuku hotel', 'Ramen dinner']),
    ('Day 2', 'Nov 13', ['Senso-ji Temple', 'Tsukiji Outer Market', 'Akihabara']),
    ('Day 3', 'Nov 14', ['Shinjuku Gyoen', 'Shibuya Crossing', 'Harajuku']),
    ('Day 4', 'Nov 15', ['Depart Tokyo → Kyoto (Shinkansen)', 'Fushimi Inari Taisha']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Plan', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorInkSoft,
            onPressed: () {},
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(kSpace4),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(height: kSpace4),
        itemBuilder: (context, i) {
          final (day, date, items) = _days[i];
          return _DayCard(day: day, date: date, items: items);
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.date, required this.items});
  final String day;
  final String date;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace3),
            child: Row(
              children: [
                Text(day, style: kStyleBodyBold),
                const SizedBox(width: kSpace2),
                Text('·', style: kStyleCaption),
                const SizedBox(width: kSpace2),
                Text(
                  date,
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kTextSm,
                    color: kColorInkSoft,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: kSpace4,
                vertical: kSpace2,
              ),
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: kColorPrimarySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: kStyleOverline.copyWith(
                      color: kColorPrimaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              title: Text(items[i], style: kStyleBody),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: kColorTextTertiary(),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
