import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'shared/settings_sections.dart';

/// Desktop Settings. Mobile reaches the same sections from More — both are
/// built from `shared/settings_sections.dart`, so keep new rows there.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text('Settings', style: kStyleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: const [
          SettingsSection(title: 'Account', child: AccountSettingsCard()),
          SettingsSection(title: 'Trip', child: TripSettingsCard()),
          AppSettingsSections(),
          SizedBox(height: kSpace12),
        ],
      ),
    );
  }
}
