import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

const _kOnboardingShownKey = 'onboarding_v1_shown';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingShownKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingShownKey, true);
}

Future<void> showOnboardingIfNeeded(BuildContext context) async {
  final seen = await hasSeenOnboarding();
  if (seen || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _OnboardingDialog(),
  );
  await markOnboardingSeen();
}

// ─── Onboarding data ──────────────────────────────────────────────────────────

class _Page {
  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

const _kPages = [
  _Page(
    icon: Icons.flight_rounded,
    title: 'Welcome to WabWay',
    body:
        'Plan your group trip in one place — spots, itinerary, shared expenses, and travel bookings, all in sync with your crew.',
    color: kColorPrimary,
  ),
  _Page(
    icon: Icons.place_rounded,
    title: 'Discover & vote on Spots',
    body:
        'Add places you want to visit, vote Must-do / Want / Maybe / Skip, and confirm the ones you\'re committing to. Confirmed spots flow straight into your plan.',
    color: Color(0xFFC96F4A),
  ),
  _Page(
    icon: Icons.event_note_rounded,
    title: 'Build your itinerary',
    body:
        'Organize trip days city-by-city. Add spots, meals, activities, and transport. Drag items to reorder within a day, or move them between days.',
    color: Color(0xFF4A7AB5),
  ),
  _Page(
    icon: Icons.receipt_long_rounded,
    title: 'Split expenses fairly',
    body:
        'Log receipts with who paid and who\'s splitting. WabWay calculates balances and suggests the fewest transfers to settle up — no spreadsheets needed.',
    color: Color(0xFFD6A84F),
  ),
  _Page(
    icon: Icons.folder_rounded,
    title: 'Keep documents together',
    body:
        'Attach booking confirmations, passport photos, and receipts so every document is one tap away, even offline. Share any file directly from the app.',
    color: Color(0xFF7D9A75),
  ),
];

// ─── Dialog ───────────────────────────────────────────────────────────────────

class _OnboardingDialog extends StatefulWidget {
  const _OnboardingDialog();

  @override
  State<_OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<_OnboardingDialog> {
  final _ctrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _kPages.length - 1) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _skip() => Navigator.pop(context);

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _kPages.length - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace6),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusLg,
        ),
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _kPages.length,
                itemBuilder: (_, i) => _OnboardingPage(page: _kPages[i]),
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _kPages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: kSpace3),
                  width: i == _page ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? kColorPrimary : kColorBorder,
                    borderRadius: kRadiusPill,
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
              child: Row(
                children: [
                  if (!isLast)
                    Expanded(
                      child: WabwayButton(
                        label: 'Skip',
                        variant: WabwayButtonVariant.ghost,
                        onPressed: _skip,
                      ),
                    ),
                  if (!isLast) const SizedBox(width: kSpace3),
                  Expanded(
                    flex: 2,
                    child: WabwayButton(
                      label: isLast ? 'Get started' : 'Next',
                      icon: isLast
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});
  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(kSpace5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 36, color: page.color),
          ),
          const SizedBox(height: kSpace5),
          Text(
            page.title,
            style: kStyleTitle.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: kSpace3),
          Text(
            page.body,
            style: kStyleBody.copyWith(
              color: kColorInkSoft,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
