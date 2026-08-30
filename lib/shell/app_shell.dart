import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers/profile_provider.dart';
import '../core/connectivity_service.dart';
import '../core/providers/trip_provider.dart';
import '../widgets/offline_banner.dart';
import '../core/share/share_handler.dart';
import '../screens/share/incoming_share_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../screens/spots_screen.dart';
import '../screens/plan_screen.dart';
import '../screens/money_screen.dart';
import '../screens/docs_screen.dart';
import '../screens/more_screen.dart';
import '../screens/home_screen.dart';
import '../screens/members_screen.dart';
import '../screens/travel_screen.dart';
import '../screens/map_screen.dart';
import '../screens/links_screen.dart';
import '../screens/accommodations/accommodations_screen.dart';
import '../screens/packing_screen.dart';
import '../screens/shopping/shopping_screen.dart';
import '../screens/crew_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/trips/trip_switcher_sheet.dart';
import '../core/changelog.dart';
import '../core/notifications/notification_service.dart';

// ─── Navigation destination models ───────────────────────────────────────────

class _NavDest {
  const _NavDest({
    required this.key,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });

  final String key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;
}

// ─── Mobile — 5 bottom tab destinations ──────────────────────────────────────

const _mobileDestinations = [
  _NavDest(
    key: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    builder: _buildHome,
  ),
  _NavDest(
    key: 'spots',
    label: 'Spots',
    icon: Icons.place_outlined,
    selectedIcon: Icons.place_rounded,
    builder: _buildSpots,
  ),
  _NavDest(
    key: 'plan',
    label: 'Plan',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    builder: _buildPlan,
  ),
  _NavDest(
    key: 'money',
    label: 'Money',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    builder: _buildMoney,
  ),
  _NavDest(
    key: 'more',
    label: 'More',
    icon: Icons.more_horiz_rounded,
    selectedIcon: Icons.more_horiz_rounded,
    builder: _buildMore,
  ),
];

// ─── Desktop — 10 sidebar destinations ───────────────────────────────────────

const _desktopDestinations = [
  _NavDest(
    key: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    builder: _buildHome,
  ),
  _NavDest(
    key: 'crew',
    label: 'Crew',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group_rounded,
    builder: _buildCrew,
  ),
  _NavDest(
    key: 'spots',
    label: 'Spots',
    icon: Icons.place_outlined,
    selectedIcon: Icons.place_rounded,
    builder: _buildSpots,
  ),
  _NavDest(
    key: 'links',
    label: 'Links',
    icon: Icons.link_rounded,
    selectedIcon: Icons.link_rounded,
    builder: _buildLinks,
  ),
  _NavDest(
    key: 'map',
    label: 'Map',
    icon: Icons.map_outlined,
    selectedIcon: Icons.map_rounded,
    builder: _buildMap,
  ),
  _NavDest(
    key: 'plan',
    label: 'Plan',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    builder: _buildPlan,
  ),
  _NavDest(
    key: 'travel',
    label: 'Travel',
    icon: Icons.flight_outlined,
    selectedIcon: Icons.flight_rounded,
    builder: _buildTravel,
  ),
  _NavDest(
    key: 'stays',
    label: 'Stays',
    icon: Icons.hotel_outlined,
    selectedIcon: Icons.hotel_rounded,
    builder: _buildStays,
  ),
  _NavDest(
    key: 'money',
    label: 'Money',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet_rounded,
    builder: _buildMoney,
  ),
  _NavDest(
    key: 'documents',
    label: 'Documents',
    icon: Icons.folder_outlined,
    selectedIcon: Icons.folder_rounded,
    builder: _buildDocs,
  ),
  _NavDest(
    key: 'packing',
    label: 'Packing',
    icon: Icons.luggage_outlined,
    selectedIcon: Icons.luggage_rounded,
    builder: _buildPacking,
  ),
  _NavDest(
    key: 'shopping',
    label: 'Shopping',
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart_rounded,
    builder: _buildShopping,
  ),
  _NavDest(
    key: 'members',
    label: 'Members',
    icon: Icons.group_outlined,
    selectedIcon: Icons.group_rounded,
    builder: _buildMembers,
  ),
  _NavDest(
    key: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings_rounded,
    builder: _buildSettings,
  ),
];

// ─── Screen builder functions ─────────────────────────────────────────────────

Widget _buildHome(BuildContext _)    => const HomeScreen();
Widget _buildCrew(BuildContext _)    => const CrewScreen();
Widget _buildSpots(BuildContext _)   => const SpotsScreen();
Widget _buildLinks(BuildContext _)   => const LinksScreen();
Widget _buildMap(BuildContext _)     => const MapScreen();
Widget _buildPlan(BuildContext _)    => const PlanScreen();
Widget _buildTravel(BuildContext _)  => const TravelScreen();
Widget _buildStays(BuildContext _)   => const AccommodationsScreen();
Widget _buildMoney(BuildContext _)   => const MoneyScreen();
Widget _buildDocs(BuildContext _)    => const DocsScreen();
Widget _buildMembers(BuildContext _) => const MembersScreen();
Widget _buildPacking(BuildContext _)   => const PackingScreen();
Widget _buildShopping(BuildContext _)  => const ShoppingScreen();
Widget _buildMore(BuildContext _)      => const MoreScreen();
Widget _buildSettings(BuildContext _) => const SettingsScreen();

// ─── AppShell — responsive entry point ───────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _mobileIndex = 0;
  int _desktopIndex = 0;

  @override
  void initState() {
    super.initState();
    ShareHandler.instance.addListener(_onSharePending);
    if (!kIsWeb) NotificationService.instance.setTabSwitcher(_switchTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onSharePending();
      ChangelogService.maybeShowOnLaunch(context);
    });
  }

  @override
  void dispose() {
    ShareHandler.instance.removeListener(_onSharePending);
    super.dispose();
  }

  // Maps notification screen key → mobile tab index (desktop uses key directly).
  static const _mobileKeyToIndex = {
    'home': 0, 'spots': 1, 'plan': 2, 'money': 3, 'more': 4,
    // crew/travel/docs/links/shopping live under More on mobile — open More tab.
    'crew': 4, 'travel': 4, 'docs': 4, 'shopping': 4,
  };
  static const _desktopKeyToIndex = {
    'home': 0, 'crew': 1, 'spots': 2, 'links': 3, 'plan': 5,
    'travel': 6, 'money': 8, 'docs': 9, 'shopping': 11,
  };

  void _switchTab(String screenKey) {
    if (!mounted) return;
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    if (isDesktop) {
      final idx = _desktopKeyToIndex[screenKey];
      if (idx != null) setState(() => _desktopIndex = idx);
    } else {
      final idx = _mobileKeyToIndex[screenKey];
      if (idx != null) setState(() => _mobileIndex = idx);
    }
  }

  void _onSharePending() {
    final share = ShareHandler.instance.pending;
    if (share == null || !mounted) return;
    ShareHandler.instance.consume();
    final tripId = ref.read(activeTripIdProvider);
    final userId = ref.read(profileProvider)?.id ?? '';
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => IncomingShareScreen(
        share: share,
        tripId: tripId,
        userId: userId,
        onDone: () => Navigator.of(context).pop(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final offline = ref.watch(tripNotifierProvider).offline ||
        !ref.watch(connectivityProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
        final shell = isDesktop ? _DesktopShell(
          destinations: _desktopDestinations,
          selectedIndex: _desktopIndex,
          onDestinationSelected: (i) => setState(() => _desktopIndex = i),
        ) : _MobileShell(
          destinations: _mobileDestinations,
          selectedIndex: _mobileIndex,
          onDestinationSelected: (i) => setState(() => _mobileIndex = i),
        );
        if (!offline) return shell;
        return Stack(
          children: [
            shell,
            Positioned(
              bottom: isDesktop ? 0 : kBottomNavHeight,
              left: 0,
              right: 0,
              child: OfflineBanner(
                onRetry: () =>
                    ref.read(tripNotifierProvider.notifier).load(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Mobile shell — bottom NavigationBar ─────────────────────────────────────

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: IndexedStack(
        index: selectedIndex,
        children: destinations
            .asMap()
            .entries
            .map((e) => TickerMode(
                  enabled: e.key == selectedIndex,
                  child: e.value.builder(context),
                ))
            .toList(),
      ),
      bottomNavigationBar: _WabwayBottomNav(
        destinations: destinations,
        selectedIndex: selectedIndex,
        onTap: onDestinationSelected,
      ),
    );
  }
}

class _WabwayBottomNav extends StatelessWidget {
  const _WabwayBottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        border: Border(
          top: BorderSide(color: kColorBorder),
        ),
        boxShadow: kShadowMd,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: kBottomNavHeight,
          child: Row(
            children: destinations.asMap().entries.map((e) {
              final i = e.key;
              final dest = e.value;
              final isActive = i == selectedIndex;
              return Expanded(
                child: _BottomNavItem(
                  icon: dest.icon,
                  selectedIcon: dest.selectedIcon,
                  label: dest.label,
                  isActive: isActive,
                  onTap: () => onTap(i),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? selectedIcon : icon,
            size: 24,
            color: isActive ? kColorPrimary : kColorInkSoft,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: (isActive ? kStyleNavLabelActive : kStyleNavLabel).copyWith(
              color: isActive ? kColorPrimary : kColorInkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Desktop shell — fixed sidebar + content area ────────────────────────────

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Row(
        children: [
          _WabwaySidebar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onTap: onDestinationSelected,
          ),
          // Right border separator
          const VerticalDivider(width: 1, thickness: 1, color: kColorBorder),
          // Content area
          Expanded(
            child: IndexedStack(
              index: selectedIndex,
              children: destinations
                  .asMap()
                  .entries
                  .map((e) => TickerMode(
                        enabled: e.key == selectedIndex,
                        child: e.value.builder(context),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WabwaySidebar extends StatelessWidget {
  const _WabwaySidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_NavDest> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kSidebarWidth,
      child: ColoredBox(
        color: kColorBgRaised,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Trip switcher header
            _SidebarHeader(),
            // Nav items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
                child: Column(
                  children: destinations.asMap().entries.map((e) {
                    final i = e.key;
                    final dest = e.value;
                    final isActive = i == selectedIndex;
                    return _SidebarRow(
                      icon: dest.icon,
                      selectedIcon: dest.selectedIcon,
                      label: dest.label,
                      isActive: isActive,
                      onTap: () => onTap(i),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace3, 0, kSpace3, kSpace3),
              child: Column(
                children: [
                  _SidebarRow(
                    icon: Icons.android_rounded,
                    selectedIcon: Icons.android_rounded,
                    label: 'Download Android app',
                    isActive: false,
                    onTap: () => launchUrl(
                      Uri.parse('https://github.com/Wahbi-R/WabWay/releases/latest'),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                  _SidebarRow(
                    icon: Icons.new_releases_outlined,
                    selectedIcon: Icons.new_releases_rounded,
                    label: "What's new",
                    isActive: false,
                    onTap: () => ChangelogService.show(context),
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

class _SidebarHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip    = ref.watch(activeTripProvider);
    final hasMany = ref.watch(allTripsProvider).length > 1;

    return GestureDetector(
      onTap: () => showTripSwitcherSheet(context, ref),
      child: Padding(
        padding: const EdgeInsets.all(kSpace5),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: kColorPrimary,
                borderRadius: kRadiusXs,
              ),
              child: Center(
                child: Text(
                  'W',
                  style: kStyleTitle.copyWith(
                    color: kColorTextOnPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip?.name ?? 'WabWay',
                    style: kStyleBodyBold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    trip?.subtitle.isNotEmpty == true
                        ? trip!.subtitle
                        : 'Your trip',
                    style: kStyleOverline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasMany)
              const Icon(Icons.unfold_more_rounded, size: 16, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3),
          decoration: BoxDecoration(
            color: widget.isActive
                ? kColorPrimarySoft
                : _hovered
                    ? kColorPrimarySoft.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: kRadiusSm,
          ),
          child: Row(
            children: [
              Icon(
                widget.isActive ? widget.selectedIcon : widget.icon,
                size: 19,
                color: widget.isActive ? kColorPrimaryDark : kColorInkSoft,
              ),
              const SizedBox(width: kSpace3),
              Text(
                widget.label,
                style: kStyleBody.copyWith(
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isActive ? kColorPrimaryDark : kColorInkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
