import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

const _kPrefActivity  = 'notif_activity';
const _kPrefMoney     = 'notif_money';
const _kPrefDocuments = 'notif_documents';
const _kPrefItinerary = 'notif_itinerary';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _activity  = true;
  bool _money     = true;
  bool _documents = true;
  bool _itinerary = true;
  bool _loaded    = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _activity  = prefs.getBool(_kPrefActivity)  ?? true;
      _money     = prefs.getBool(_kPrefMoney)     ?? true;
      _documents = prefs.getBool(_kPrefDocuments) ?? true;
      _itinerary = prefs.getBool(_kPrefItinerary) ?? true;
      _loaded    = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefActivity,  _activity);
    await prefs.setBool(_kPrefMoney,     _money);
    await prefs.setBool(_kPrefDocuments, _documents);
    await prefs.setBool(_kPrefItinerary, _itinerary);
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
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
