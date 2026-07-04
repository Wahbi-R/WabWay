import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/auth/app_profile.dart';
import '../core/supabase/client.dart';
import '../core/trip/app_trip.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, this.profile, this.trip});
  final AppProfile? profile;
  final AppTrip? trip;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  String _supabaseStatus = 'checking…';
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    _checkSupabase();
    if (!kIsWeb) _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    } catch (_) {}
  }

  Future<void> _checkSupabase() async {
    try {
      await supabase.from('trips').select('id').limit(1);
      if (mounted) setState(() => _supabaseStatus = 'Connected ✓');
    } catch (e) {
      if (mounted) setState(() => _supabaseStatus = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final trip    = widget.trip;
    final url     = supabase.supabaseUrl;

    final rows = <_DiagRow>[
      _DiagRow('App version', _appVersion),
      _DiagRow('Supabase URL', url),
      _DiagRow('Supabase connection', _supabaseStatus),
      _DiagRow('User ID', profile?.id ?? '—'),
      _DiagRow('Display name', profile?.displayName ?? '—'),
      _DiagRow('Email', profile?.email ?? '—'),
      _DiagRow('Active trip ID', trip?.id ?? '—'),
      _DiagRow('Active trip name', trip?.name ?? '—'),
    ];

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Diagnostics', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Column(
              children: rows.asMap().entries.map((e) {
                final isLast = e.key == rows.length - 1;
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: kSpace4, vertical: kSpace1),
                      title: Text(e.value.label, style: kStyleCaption),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SelectableText(
                          e.value.value,
                          style: kStyleBodyMedium,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        color: kColorInkSoft,
                        tooltip: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: e.value.value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied: ${e.value.label}',
                                  style: kStyleBody.copyWith(color: Colors.white)),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: kSpace4),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: kSpace4),
          FilledButton.icon(
            onPressed: _checkSupabase,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Re-check connection'),
            style: FilledButton.styleFrom(
              backgroundColor: kColorPrimary,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: kRadiusMd),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagRow {
  const _DiagRow(this.label, this.value);
  final String label;
  final String value;
}
