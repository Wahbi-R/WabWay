import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/supabase/emergency_service.dart';
import '../core/trip/trip_state.dart';
import '../data/emergency_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  TripEmergencyInfo? _info;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final tripId = TripState.tripOf(context).id;
    final info = await EmergencyService.fetch(tripId);
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  void _edit() async {
    final tripId = TripState.tripOf(context).id;
    final result = await showModalBottomSheet<TripEmergencyInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _EditSheet(tripId: tripId, existing: _info),
    );
    if (result != null && mounted) {
      setState(() => _info = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const WabwayLoadingScaffold();

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Emergency Info', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, size: 20),
            color: kColorInkSoft,
            tooltip: 'Edit',
            onPressed: _edit,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _info == null || _info!.isEmpty
          ? _EmptyState(onEdit: _edit)
          : _InfoBody(info: _info!),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.health_and_safety_rounded, size: 48, color: kColorInkSoft),
          const SizedBox(height: 16),
          Text('No emergency info yet', style: kStyleBodyMedium),
          const SizedBox(height: 8),
          Text(
            'Add insurance numbers, emergency contacts,\nand local emergency info before your trip.',
            style: kStyleCaption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add info'),
            style: FilledButton.styleFrom(backgroundColor: kColorPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Info body ────────────────────────────────────────────────────────────────

class _InfoBody extends StatelessWidget {
  const _InfoBody({required this.info});
  final TripEmergencyInfo info;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(kSpace4),
      children: [
        if (info.localEmergencyNum != null)
          _Section(
            icon: Icons.emergency_rounded,
            iconColor: const Color(0xFFD64242),
            title: 'Local Emergency Number',
            items: [
              _InfoRow(
                label: 'Call',
                value: info.localEmergencyNum!,
                onTap: () => _dialPhone(info.localEmergencyNum!),
                actionIcon: Icons.call_rounded,
              ),
            ],
          ),
        if (info.insuranceProvider != null ||
            info.insurancePolicyNum != null ||
            info.insurancePhone != null)
          _Section(
            icon: Icons.shield_rounded,
            iconColor: const Color(0xFF4A7AB5),
            title: 'Travel Insurance',
            items: [
              if (info.insuranceProvider != null)
                _InfoRow(label: 'Provider', value: info.insuranceProvider!),
              if (info.insurancePolicyNum != null)
                _InfoRow(
                  label: 'Policy #',
                  value: info.insurancePolicyNum!,
                  copyable: true,
                  mono: true,
                ),
              if (info.insurancePhone != null)
                _InfoRow(
                  label: 'Phone',
                  value: info.insurancePhone!,
                  onTap: () => _dialPhone(info.insurancePhone!),
                  actionIcon: Icons.call_rounded,
                ),
            ],
          ),
        if (info.cardEmergencyPhone != null)
          _Section(
            icon: Icons.credit_card_rounded,
            iconColor: const Color(0xFF7D9A75),
            title: 'Credit Card Emergency',
            items: [
              _InfoRow(
                label: 'Phone',
                value: info.cardEmergencyPhone!,
                onTap: () => _dialPhone(info.cardEmergencyPhone!),
                actionIcon: Icons.call_rounded,
              ),
            ],
          ),
        if (info.nearestHospital != null)
          _Section(
            icon: Icons.local_hospital_rounded,
            iconColor: const Color(0xFFD6A84F),
            title: 'Nearest Hospital / Clinic',
            items: [
              _InfoRow(
                label: 'Location',
                value: info.nearestHospital!,
                copyable: true,
              ),
            ],
          ),
        if (info.embassyContacts.isNotEmpty)
          _Section(
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF8A7F75),
            title: 'Embassy Contacts',
            items: [
              for (final e in info.embassyContacts) ...[
                _InfoRow(label: 'Country', value: e.country),
                if (e.phone != null)
                  _InfoRow(
                    label: 'Phone',
                    value: e.phone!,
                    onTap: () => _dialPhone(e.phone!),
                    actionIcon: Icons.call_rounded,
                  ),
                if (e.address != null)
                  _InfoRow(label: 'Address', value: e.address!, copyable: true),
                const Divider(height: kSpace4, thickness: 1, color: kColorBorder),
              ],
            ],
          ),
        if (info.notes != null)
          _Section(
            icon: Icons.notes_rounded,
            iconColor: kColorInkSoft,
            title: 'Notes',
            items: [
              Padding(
                padding: const EdgeInsets.only(top: kSpace2),
                child: Text(info.notes!, style: kStyleBody),
              ),
            ],
          ),
        const SizedBox(height: kSpace16),
      ],
    );
  }

  void _dialPhone(String number) {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    launchUrl(uri);
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: WabwayCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: kSpace2),
                Text(title, style: kStyleCaptionMedium.copyWith(color: iconColor)),
              ],
            ),
            const SizedBox(height: kSpace3),
            ...items,
          ],
        ),
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.mono = false,
    this.onTap,
    this.actionIcon,
  });
  final String label;
  final String value;
  final bool copyable;
  final bool mono;
  final VoidCallback? onTap;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(
      value,
      style: mono
          ? const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: kColorInk)
          : kStyleBodyMedium,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: kStyleCaption),
          ),
          Expanded(child: valueText),
          if (copyable)
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 2)),
                  );
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.copy_rounded, size: 14, color: kColorInkSoft),
              ),
            ),
          if (onTap != null && actionIcon != null)
            GestureDetector(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(actionIcon, size: 18, color: kColorPrimary),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Edit sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.tripId, this.existing});
  final String tripId;
  final TripEmergencyInfo? existing;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _insuranceProvider   = TextEditingController(text: widget.existing?.insuranceProvider);
  late final _insurancePolicyNum  = TextEditingController(text: widget.existing?.insurancePolicyNum);
  late final _insurancePhone      = TextEditingController(text: widget.existing?.insurancePhone);
  late final _cardPhone           = TextEditingController(text: widget.existing?.cardEmergencyPhone);
  late final _localEmergency      = TextEditingController(text: widget.existing?.localEmergencyNum);
  late final _hospital            = TextEditingController(text: widget.existing?.nearestHospital);
  late final _notes               = TextEditingController(text: widget.existing?.notes);

  bool _saving = false;

  @override
  void dispose() {
    _insuranceProvider.dispose();
    _insurancePolicyNum.dispose();
    _insurancePhone.dispose();
    _cardPhone.dispose();
    _localEmergency.dispose();
    _hospital.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final base = existing ?? TripEmergencyInfo(id: '', tripId: widget.tripId);
      final updated = base.copyWith(
        insuranceProvider:  _n(_insuranceProvider.text),
        insurancePolicyNum: _n(_insurancePolicyNum.text),
        insurancePhone:     _n(_insurancePhone.text),
        cardEmergencyPhone: _n(_cardPhone.text),
        localEmergencyNum:  _n(_localEmergency.text),
        nearestHospital:    _n(_hospital.text),
        notes:              _n(_notes.text),
      );
      final saved = await EmergencyService.upsert(widget.tripId, updated);
      if (mounted) Navigator.pop(context, saved);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  // Null-coerce empty strings
  String? _n(String s) => s.trim().isEmpty ? null : s.trim();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: kColorBorder, borderRadius: kRadiusPill),
              ),
            ),
            const SizedBox(height: 16),
            Text('Emergency Info', style: kStyleTitle),
            const SizedBox(height: 20),
            _label('Local emergency number'),
            _field(_localEmergency, hint: '112 / 911 / 110'),
            _label('Travel insurance provider'),
            _field(_insuranceProvider, hint: 'e.g. Allianz, Blue Cross'),
            _label('Policy number'),
            _field(_insurancePolicyNum, hint: 'Policy #'),
            _label('Insurance emergency phone'),
            _field(_insurancePhone, hint: '+1 800 …', keyboard: TextInputType.phone),
            _label('Credit card emergency phone'),
            _field(_cardPhone, hint: '+1 800 …', keyboard: TextInputType.phone),
            _label('Nearest hospital / clinic'),
            _field(_hospital, hint: 'Name or address'),
            _label('Notes'),
            _field(_notes, hint: 'Anything else…', maxLines: 3),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: kColorPrimary),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: kSpace3, bottom: 4),
        child: Text(text, style: kStyleCaption),
      );

  Widget _field(TextEditingController ctrl, {String? hint, int maxLines = 1, TextInputType? keyboard}) =>
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboard,
        style: kStyleBodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
          filled: true,
          fillColor: kColorCream,
          border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      );
}
