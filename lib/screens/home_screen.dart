import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Home', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: kColorInkSoft,
            onPressed: () {},
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
          // Trip hero card
          _TripHero(),
          const SizedBox(height: kSpace4),

          // Balance card
          _QuickBalanceCard(),
          const SizedBox(height: kSpace4),

          // Activity feed
          Text('Recent activity', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          _ActivityFeed(),
          const SizedBox(height: kSpace16),
        ],
      ),
    );
  }
}

class _TripHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRIP',
              style: kStyleOverline.copyWith(
                color: kColorPrimary,
                letterSpacing: kTextXs * kTrackingWide,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              'Japan, November',
              style: GoogleFonts.lora(
                fontSize: kText2xl,
                fontWeight: FontWeight.w600,
                color: kColorInk,
                height: kLeadingSnug,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text('Nov 12 – Nov 22, 2024  ·  4 members', style: kStyleCaption),
            const SizedBox(height: kSpace5),
            const Row(
              children: [
                _HeroStat(label: 'Spots saved', value: '18'),
                SizedBox(width: kSpace6),
                _HeroStat(label: 'Days planned', value: '10'),
                SizedBox(width: kSpace6),
                _HeroStat(label: 'Total spent', value: '¥142k'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            fontSize: kTextXl,
            fontWeight: FontWeight.w600,
            color: kColorInk,
          ),
        ),
        Text(label, style: kStyleCaption),
      ],
    );
  }
}

class _QuickBalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorPrimarySoftBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: kColorPrimary, size: 20),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your balance', style: kStyleCaption),
                  const SizedBox(height: kSpace1),
                  Text(
                    'You owe Alex: ¥3,200',
                    style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
                  ),
                  Text(
                    'You are owed: Jordan ¥5,000',
                    style: kStyleBodySemibold.copyWith(color: kColorSuccess),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: kColorPrimaryDark,
                backgroundColor: kColorPaper,
                shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
              ),
              child: Text('Settle up', style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFeed extends StatelessWidget {
  static const _items = [
    (Icons.receipt_long_rounded, 'Alex added a receipt', 'Ramen Ichiran · ¥4,800', '2h ago'),
    (Icons.place_rounded, 'Jordan saved a spot', 'Dotonbori · Osaka', '5h ago'),
    (Icons.calendar_month_rounded, 'Sam updated the plan', 'Added Day 4 itinerary', 'Yesterday'),
    (Icons.people_rounded, 'You joined the trip', 'Japan, November', '3 days ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Column(
        children: _items.asMap().entries.map((e) {
          final i = e.key;
          final (icon, title, sub, time) = e.value;
          final isLast = i == _items.length - 1;
          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace2,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: kColorSurfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: kColorInkSoft),
                ),
                title: Text(title, style: kStyleBodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub, style: kStyleCaption),
                ),
                trailing: Text(time, style: kStyleOverline),
              ),
              if (!isLast) const Divider(height: 1, indent: kSpace4 + 36 + kSpace3),
            ],
          );
        }).toList(),
      ),
    );
  }
}
