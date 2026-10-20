import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import 'accommodations/accommodations_screen.dart';
import 'crew_screen.dart';
import 'map_screen.dart';
import 'travel_screen.dart';
import 'packing_screen.dart';
import 'shopping/shopping_screen.dart';
import 'photos_screen.dart';
import 'members/add_member_sheet.dart';
import 'members/invite_sheet.dart';
import 'trips/trip_switcher_sheet.dart';
import 'trips/trip_actions.dart';
import 'library_screen.dart';
import 'shared/settings_sections.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(tripMembersProvider);
    final trip = ref.watch(activeTripProvider);
    final currentUserId = ref.watch(profileProvider)?.id;
    final isOwner = ref.watch(isOrganiserProvider);
    final reload = () => ref.read(tripNotifierProvider.notifier).load();

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text('More', style: kStyleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
          // Trip switcher
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace1,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusMd,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      size: 20, color: kColorPrimary),
                ),
                title: Text(trip?.name ?? '', style: kStyleBodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Tap to switch trip', style: kStyleCaption),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: kColorTextTertiary(), size: 18),
                onTap: () => showTripSwitcherSheet(context, ref),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Crew / Chat — prominent card for quick access
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace1,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusMd,
                  ),
                  child: const Icon(Icons.chat_rounded,
                      size: 20, color: kColorPrimary),
                ),
                title: Text('Crew Chat', style: kStyleBodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Message your trip crew & share location',
                      style: kStyleCaption),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: kColorTextTertiary(), size: 18),
                onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const CrewScreen())),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Members section
          Text('Members', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: members.asMap().entries.map((e) {
                  final i = e.key;
                  final member = e.value;
                  final isLast = i == members.length - 1;
                  final isMe = member.userId == currentUserId;
                  final displayName = isMe
                      ? '${member.profile.displayName} (You)'
                      : member.profile.displayName;
                  final canRemove = isOwner && !isMe && !member.isOwner;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: kSpace4,
                          vertical: kSpace2,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: kColorPrimarySoft,
                          child: Text(
                            member.profile.initials,
                            style: kStyleBodySemibold.copyWith(
                                color: kColorPrimaryDark),
                          ),
                        ),
                        title: Text(displayName, style: kStyleBodyMedium),
                        subtitle:
                            Text(member.profile.email, style: kStyleCaption),
                        trailing: member.isOwner
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpace2,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: kColorAccentSoft,
                                  borderRadius: kRadiusPill,
                                ),
                                child: Text(
                                  'Organiser',
                                  style: kStyleOverline.copyWith(
                                      color: kColorAccent),
                                ),
                              )
                            : canRemove
                                ? IconButton(
                                    icon: const Icon(Icons.person_remove_outlined,
                                        size: 18, color: kColorDanger),
                                    tooltip: 'Remove member',
                                    onPressed: () => confirmRemoveMember(
                                        context, trip?.id ?? '', member, reload),
                                  )
                                : null,
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1, indent: kSpace4 + 36 + kSpace3),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Screens not in the mobile bottom nav
          const _SectionHeader(title: 'Explore'),
          const SizedBox(height: kSpace3),
          _ExploreGrid(items: [
            _ExploreItem(icon: Icons.map_rounded,           label: 'Map',       onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
            _ExploreItem(icon: Icons.flight_rounded,        label: 'Travel',    onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const TravelScreen()))),
            _ExploreItem(icon: Icons.photo_library_rounded, label: 'Photos',    onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const PhotosScreen()))),
            _ExploreItem(icon: Icons.hotel_rounded,         label: 'Stays',     onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AccommodationsScreen()))),
            _ExploreItem(icon: Icons.folder_rounded,        label: 'Library',   onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LibraryScreen()))),
            _ExploreItem(icon: Icons.luggage_rounded,       label: 'Packing',   onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const PackingScreen()))),
            _ExploreItem(icon: Icons.shopping_cart_rounded, label: 'Shopping',  onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const ShoppingScreen()))),
          ]),

          const SizedBox(height: kSpace4),

          // Invite section — any trip member (hidden until trip data is loaded)
          if (trip != null) ...[
            const _SectionHeader(title: 'Invite'),
            const SizedBox(height: kSpace3),
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    if (isOwner) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.all(kSpace4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: kColorPrimarySoft,
                            borderRadius: kRadiusMd,
                          ),
                          child: const Icon(Icons.person_add_rounded,
                              size: 20, color: kColorPrimary),
                        ),
                        title: Text('Add a member', style: kStyleBodySemibold),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: kSpace1),
                          child: Text('Add an existing WabWay user by email',
                              style: kStyleCaption),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: kColorTextTertiary()),
                        onTap: () => showAddMemberSheet(
                          context,
                          tripId: trip.id,
                          existingMemberIds: members.map((m) => m.userId).toSet(),
                          onMemberAdded: reload,
                        ),
                      ),
                      const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    ],
                    ListTile(
                      contentPadding: const EdgeInsets.all(kSpace4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: kColorPrimarySoft,
                          borderRadius: kRadiusMd,
                        ),
                        child: const Icon(Icons.key_rounded,
                            size: 20, color: kColorPrimary),
                      ),
                      title: Text('Create invite code', style: kStyleBodySemibold),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: kSpace1),
                        child: Text('Generate a code anyone can use to join',
                            style: kStyleCaption),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: kColorTextTertiary()),
                      onTap: () => showInviteSheet(context, tripId: trip.id, canRevoke: isOwner),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: kSpace4),

          const SettingsSection(title: 'Trip', child: TripSettingsCard(showInvite: false)),
          const SettingsSection(title: 'Account', child: AccountSettingsCard()),
          const AppSettingsSections(),

          const SizedBox(height: kSpace16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: kStyleOverline);
}

class _ExploreItem {
  const _ExploreItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid({required this.items});
  final List<_ExploreItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(kSpace2),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.85,
          children: items.map((item) => _ExploreGridItem(item: item)).toList(),
        ),
      ),
    );
  }
}

class _ExploreGridItem extends StatelessWidget {
  const _ExploreGridItem({required this.item});
  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusSm,
            ),
            child: Icon(item.icon, size: 20, color: kColorInkSoft),
          ),
          const SizedBox(height: kSpace1),
          Text(
            item.label,
            style: kStyleCaption.copyWith(fontWeight: FontWeight.w600, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

