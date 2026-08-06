import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// Keys used by push_notifier.dart to gate notification sends.
const kPrefNotifCrew      = 'notif_crew';
const kPrefNotifActivity  = 'notif_activity';
const kPrefNotifMoney     = 'notif_money';
const kPrefNotifDocuments = 'notif_documents';
const kPrefNotifItinerary = 'notif_itinerary';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool _crew      = true;
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
      _crew      = prefs.getBool(kPrefNotifCrew)      ?? true;
      _activity  = prefs.getBool(kPrefNotifActivity)  ?? true;
      _money     = prefs.getBool(kPrefNotifMoney)     ?? true;
      _documents = prefs.getBool(kPrefNotifDocuments) ?? true;
      _itinerary = prefs.getBool(kPrefNotifItinerary) ?? true;
      _loaded    = true;
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPrefNotifCrew,      _crew);
    await prefs.setBool(kPrefNotifActivity,  _activity);
    await prefs.setBool(kPrefNotifMoney,     _money);
    await prefs.setBool(kPrefNotifDocuments, _documents);
    await prefs.setBool(kPrefNotifItinerary, _itinerary);
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
              'Choose which activity sends you a push notification.',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace5),
            _SectionCard(
              children: [
                _NotifRow(
                  icon: Icons.chat_rounded,
                  label: 'Crew chat',
                  description: 'New messages from your trip crew',
                  value: _crew,
                  onChanged: (v) { setState(() => _crew = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.place_rounded,
                  label: 'Spots',
                  description: 'New spots added by crew members',
                  value: _activity,
                  onChanged: (v) { setState(() => _activity = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'Money',
                  description: 'New receipts and withdrawals',
                  value: _money,
                  onChanged: (v) { setState(() => _money = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.flight_rounded,
                  label: 'Travel',
                  description: 'New flights, hotels, and bookings',
                  value: _itinerary,
                  onChanged: (v) { setState(() => _itinerary = v); _save(); },
                ),
                const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                _NotifRow(
                  icon: Icons.folder_rounded,
                  label: 'Documents',
                  description: 'New documents added to the trip',
                  value: _documents,
                  onChanged: (v) { setState(() => _documents = v); _save(); },
                ),
              ],
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
