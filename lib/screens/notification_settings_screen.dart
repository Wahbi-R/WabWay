import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

// In-session store — push notification persistence comes later.
class _NotifPrefs {
  static bool activity  = true;
  static bool money     = true;
  static bool documents = true;
  static bool itinerary = true;
}

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late bool _activity;
  late bool _money;
  late bool _documents;
  late bool _itinerary;

  @override
  void initState() {
    super.initState();
    _activity  = _NotifPrefs.activity;
    _money     = _NotifPrefs.money;
    _documents = _NotifPrefs.documents;
    _itinerary = _NotifPrefs.itinerary;
  }

  void _save() {
    _NotifPrefs.activity  = _activity;
    _NotifPrefs.money     = _money;
    _NotifPrefs.documents = _documents;
    _NotifPrefs.itinerary = _itinerary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Notifications', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose which activity generates a notification. Push delivery will be available in a future update.',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace5),
            _SectionCard(
              children: [
                _NotifRow(
                  icon: Icons.timeline_rounded,
                  label: 'Activity feed',
                  description: 'New events in the trip activity feed',
                  value: _activity,
                  onChanged: (v) { setState(() => _activity = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'Money',
                  description: 'New receipts, withdrawals, and settlements',
                  value: _money,
                  onChanged: (v) { setState(() => _money = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.folder_rounded,
                  label: 'Documents',
                  description: 'New documents added to the trip',
                  value: _documents,
                  onChanged: (v) { setState(() => _documents = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.map_rounded,
                  label: 'Itinerary',
                  description: 'Plan changes and new travel bookings',
                  value: _itinerary,
                  onChanged: (v) { setState(() => _itinerary = v); _save(); },
                ),
              ],
            ),
            const SizedBox(height: kSpace5),
            WabwayEmptyState(
              icon: Icons.notifications_off_rounded,
              title: 'Push notifications coming soon',
              description:
                  'These settings will control which push notifications you receive. Push delivery is not yet active.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
        boxShadow: kShadowSm,
      ),
      child: Column(children: children),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpace4, vertical: kSpace3),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kColorCream,
              borderRadius: kRadiusMd,
            ),
            child: Icon(icon, size: 20, color: kColorInkSoft),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kStyleBodyMedium),
                Text(description, style: kStyleCaption),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: kColorPrimary,
          ),
        ],
      ),
    );
  }
}
