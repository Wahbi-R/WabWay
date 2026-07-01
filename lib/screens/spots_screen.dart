import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/widgets.dart';

class SpotsScreen extends StatelessWidget {
  const SpotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Spots', style: kStyleTitle),
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search_rounded),
                color: kColorInkSoft,
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                color: kColorInkSoft,
                onPressed: () {},
              ),
              const SizedBox(width: kSpace2),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(kSpace4),
            sliver: SliverList.separated(
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (context, i) => _SpotCard(index: i),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: kSpace16)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add_rounded),
        label: Text('Add a spot', style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary)),
      ),
    );
  }
}

class _SpotCard extends StatelessWidget {
  const _SpotCard({required this.index});
  final int index;

  static const _names = [
    'Senso-ji Temple',
    'Tsukiji Outer Market',
    'Arashiyama Bamboo Grove',
    'Dotonbori',
    'Fushimi Inari Taisha',
    'Shibuya Crossing',
  ];

  static const _cities = [
    'Tokyo · Landmark',
    'Tokyo · Food',
    'Kyoto · Nature',
    'Osaka · Food',
    'Kyoto · Landmark',
    'Tokyo · Experience',
  ];

  static const _statuses = [
    ('Must-do',    WabwayBadgeTone.accent),
    ('Want to go', WabwayBadgeTone.primary),
    ('Planned',    WabwayBadgeTone.secondary),
    ('Idea',       WabwayBadgeTone.neutral),
    ('Booked',     WabwayBadgeTone.success),
    ('Want to go', WabwayBadgeTone.primary),
  ];

  @override
  Widget build(BuildContext context) {
    final (status, tone) = _statuses[index];

    return WabwayCard(
      hoverable: true,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
              ),
              child: Icon(
                Icons.place_rounded,
                color: kColorInkSoft.withOpacity(0.4),
                size: 28,
              ),
            ),
            const SizedBox(width: kSpace4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _names[index],
                          style: kStyleBodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      WabwayBadge(label: status, tone: tone),
                    ],
                  ),
                  const SizedBox(height: kSpace1),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 13, color: kColorTextTertiary()),
                      const SizedBox(width: 4),
                      Text(_cities[index], style: kStyleCaption),
                    ],
                  ),
                  const SizedBox(height: kSpace2),
                  Row(
                    children: [
                      _VoteChip(emoji: '👍', count: index + 2, active: true),
                      const SizedBox(width: kSpace2),
                      _VoteChip(emoji: '❤️', count: index % 2 + 1, active: false),
                    ],
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

class _VoteChip extends StatelessWidget {
  const _VoteChip({required this.emoji, required this.count, required this.active});
  final String emoji;
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 3),
      decoration: BoxDecoration(
        color: active ? kColorAccentSoft : const Color(0xFFEEEAE3),
        borderRadius: kRadiusPill,
        border: Border.all(color: active ? kColorAccentSoftBorder : kColorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text('$count', style: kStyleOverline.copyWith(color: kColorInkSoft)),
        ],
      ),
    );
  }
}
