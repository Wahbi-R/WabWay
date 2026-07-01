import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/widgets.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            title: Text('Money', style: kStyleTitle),
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                color: kColorInkSoft,
                onPressed: () {},
              ),
              const SizedBox(width: kSpace2),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Receipts'),
                Tab(text: 'Cash'),
              ],
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
              child: _BalanceSummary(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: const [
            _ReceiptsList(),
            _CashList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text(
          'Add receipt',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace4),
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorPrimarySoftBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You owe Alex', style: kStyleCaption),
                const SizedBox(height: kSpace1),
                Text(
                  '¥3,200',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kText2xl,
                    fontWeight: FontWeight.w600,
                    color: kColorPrimaryDark,
                  ),
                ),
              ],
            ),
          ),
          WabwayButton(
            label: 'Settle up',
            variant: WabwayButtonVariant.ghost,
            size: WabwayButtonSize.sm,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _ReceiptsList extends StatelessWidget {
  const _ReceiptsList();

  static const _receipts = [
    ('Ramen Ichiran',             'Alex',   '¥4,800',  'Nov 12'),
    ('Shinkansen tickets',        'You',    '¥27,400', 'Nov 15'),
    ('Hotel Shinjuku (2 nights)', 'Jordan', '¥36,000', 'Nov 12'),
    ('Tsukiji breakfast',         'You',    '¥3,200',  'Nov 13'),
    ('Convenience store run',     'Sam',    '¥1,450',  'Nov 13'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(kSpace4),
      itemCount: _receipts.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
      itemBuilder: (context, i) {
        final (name, payer, amount, date) = _receipts[i];
        final isYou = payer == 'You';
        return WabwayCard(
          child: ListTile(
            contentPadding: const EdgeInsets.all(kSpace4),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 20,
                color: kColorInkSoft,
              ),
            ),
            title: Text(name, style: kStyleBodyBold),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: kSpace1),
              child: Text('Paid by $payer · $date', style: kStyleCaption),
            ),
            trailing: Text(
              amount,
              style: GoogleFonts.ibmPlexMono(
                fontSize: kTextBase,
                fontWeight: FontWeight.w600,
                color: isYou ? kColorPrimaryDark : kColorInk,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CashList extends StatelessWidget {
  const _CashList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(kSpace4),
      children: [
        WabwayCard(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.atm_rounded, size: 18, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Text('ATM withdrawal', style: kStyleBodySemibold),
                  const Spacer(),
                  Text(
                    '¥50,000',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: kTextBase,
                      fontWeight: FontWeight.w600,
                      color: kColorInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: kSpace3),
              const Divider(height: 1),
              const SizedBox(height: kSpace3),
              Text('Split to members', style: kStyleCaption),
              const SizedBox(height: kSpace2),
              ...[
                ('Alex',   '¥12,500'),
                ('You',    '¥12,500'),
                ('Jordan', '¥12,500'),
                ('Sam',    '¥12,500'),
              ].map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: kSpace2),
                  child: Row(
                    children: [
                      WabwayAvatar(
                        name: e.$1,
                        size: WabwayAvatarSize.xs,
                      ),
                      const SizedBox(width: kSpace2),
                      Text(e.$1, style: kStyleBodyMedium),
                      const Spacer(),
                      Text(
                        e.$2,
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: kTextSm,
                          color: kColorInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
