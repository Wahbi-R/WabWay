import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.body,
  });

  final String title;
  final IconData icon;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text(title, style: kStyleTitle)),
      body: Center(
        child: WabwayEmptyState(
          icon: icon,
          title: 'Nothing here yet',
          description: body ?? '$title is coming soon.',
        ),
      ),
    );
  }
}

class LinksScreen extends StatelessWidget {
  const LinksScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Links',
    icon: Icons.link_rounded,
    body: 'Saved Instagram, TikTok, and Maps links will appear here.',
  );
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Map',
    icon: Icons.map_rounded,
    body: 'A shared map with all your saved spots will appear here.',
  );
}

class TravelScreen extends StatelessWidget {
  const TravelScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Travel',
    icon: Icons.flight_rounded,
    body: 'Flights, trains, and accommodation bookings will appear here.',
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderScreen(
    title: 'Settings',
    icon: Icons.settings_rounded,
    body: 'Trip settings, invite codes, and notifications will appear here.',
  );
}
