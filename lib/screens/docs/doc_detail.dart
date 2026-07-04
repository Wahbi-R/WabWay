import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/money_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../core/supabase/trip_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/plan_data.dart';
import '../../data/spot_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'doc_card.dart';
import '../money/add_receipt_sheet.dart';

// ── Member name helper ────────────────────────────────────────────────────────

String _uploaderName(BuildContext context, String userId) {
  final myId =
      supabase.auth.currentUser?.id ?? ProfileState.maybeOf(context)?.id;
  if (myId != null && userId == myId) return 'You';
  final members = TripState.membersOf(context);
  final match = members.where((m) => m.userId == userId).firstOrNull;
  if (match != null) return match.profile.displayName;
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

// ── Linked label helper ───────────────────────────────────────────────────────

String _linkedLabel(DocumentLink link, List<Spot> spots, String tripName) {
  switch (link.type) {
    case DocLinkedType.spot:
      return spots.where((s) => s.id == link.linkedId).firstOrNull?.name ??
          'Spot';
    case DocLinkedType.trip:
      return tripName;
    default:
      return link.type.label;
  }
}

// ── Link key helper ───────────────────────────────────────────────────────────

String _linkKey(DocumentLink link) => '${link.type.name}_${link.linkedId}';

// ── Mobile screen ─────────────────────────────────────────────────────────────

class DocDetailScreen extends StatelessWidget {
  const DocDetailScreen({
    super.key,
    required this.doc,
    required this.tripId,
    required this.tripName,
    this.availableSpots = const [],
    this.onDelete,
    this.onRenamed,
  });

  final TripDocument doc;
  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(doc.title, style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: kColorInkSoft,
            onPressed: () => _showActionsSheet(
              context,
              doc: doc,
              tripId: tripId,
              onDelete: onDelete,
              onRenamed: onRenamed,
            ),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        child: DocDetailContent(
          doc: doc,
          tripId: tripId,
          tripName: tripName,
          availableSpots: availableSpots,
          onDelete: onDelete,
          onRenamed: onRenamed,
        ),
      ),
    );
  }
}

// ── Shared content ────────────────────────────────────────────────────────────

class DocDetailContent extends StatefulWidget {
  const DocDetailContent({
    super.key,
    required this.doc,
    required this.tripId,
    required this.tripName,
    this.availableSpots = const [],
    this.onDelete,
    this.onRenamed,
  });

  final TripDocument doc;
  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;

  @override
  State<DocDetailContent> createState() => _DocDetailContentState();
}

class _DocDetailContentState extends State<DocDetailContent> {
  late List<DocumentLink> _links;
  bool _linkLoading = false;
  final Set<String> _unlinkingKeys = {};

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.doc.links);
  }

  @override
  void didUpdateWidget(DocDetailContent old) {
    super.didUpdateWidget(old);
    if (widget.doc.id != old.doc.id) {
      // Different doc selected on desktop — reset everything.
      _links = List.from(widget.doc.links);
      _unlinkingKeys.clear();
    } else if (!_linkLoading && _unlinkingKeys.isEmpty) {
      // Same doc, no operation in flight — accept server state so Realtime
      // updates from other accounts are reflected immediately.
      _links = List.from(widget.doc.links);
    }
  }

  Future<void> _addLink(DocLinkedType type, String linkedId) async {
    if (_links.any((l) => l.type == type && l.linkedId == linkedId)) return;
    // Capture context-dependent values before the async gap.
    final userId =
        supabase.auth.currentUser?.id ?? ProfileState.of(context).id;
    setState(() => _linkLoading = true);
    try {
      await DocService.addLink(
        documentId: widget.doc.id,
        linkedType: type,
        linkedId: linkedId,
        createdBy: userId,
      );
      if (!mounted) return;
      setState(() {
        _links = [..._links, DocumentLink(type: type, linkedId: linkedId)];
        _linkLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkLoading = false);
      _snack('Could not add link. Please try again.');
    }
  }

  Future<void> _removeLink(DocumentLink link) async {
    final key = _linkKey(link);
    setState(() => _unlinkingKeys.add(key));
    try {
      await DocService.deleteLink(
        documentId: widget.doc.id,
        linkedType: link.type,
        linkedId: link.linkedId,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.where((l) => _linkKey(l) != key).toList();
        _unlinkingKeys.remove(key);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlinkingKeys.remove(key));
      _snack('Could not remove link. Please try again.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorDanger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showLinkPicker() {
    final alreadyLinked = _links
        .map((l) => '${l.type.name}_${l.linkedId}')
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => _LinkPickerSheet(
        tripId: widget.tripId,
        tripName: widget.tripName,
        availableSpots: widget.availableSpots,
        alreadyLinked: alreadyLinked,
        onPick: (type, linkedId) {
          Navigator.pop(ctx);
          _addLink(type, linkedId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocHeader(doc: widget.doc),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FileMetaCard(doc: widget.doc),
              if (widget.doc.isImage && widget.doc.storagePath != null) ...[
                const SizedBox(height: kSpace4),
                _ImagePreview(storagePath: widget.doc.storagePath!),
              ],
              const SizedBox(height: kSpace4),
              _LinkedSection(
                links: _links,
                availableSpots: widget.availableSpots,
                tripName: widget.tripName,
                linkLoading: _linkLoading,
                unlinkingKeys: _unlinkingKeys,
                onAddLink: _showLinkPicker,
                onRemoveLink: _removeLink,
              ),
              if (widget.doc.notes != null &&
                  widget.doc.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                WabwayNotesSection(notes: widget.doc.notes!),
              ],
              const SizedBox(height: kSpace4),
              _ActionsSection(
                doc: widget.doc,
                tripId: widget.tripId,
                onDelete: widget.onDelete,
                onRenamed: widget.onRenamed,
                onLinkAdded: (type, linkedId) {
                  if (!_links.any((l) => l.type == type && l.linkedId == linkedId)) {
                    setState(() => _links = [..._links, DocumentLink(type: type, linkedId: linkedId)]);
                  }
                },
              ),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header band ───────────────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  const _DocHeader({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace6, kSpace4, kSpace5),
      decoration: BoxDecoration(color: doc.type.softColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: doc.type.color.withValues(alpha: 0.12),
                  borderRadius: kRadiusLg,
                ),
                child: Icon(doc.type.icon, size: 28, color: doc.type.color),
              ),
              const SizedBox(width: kSpace3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayEntityBadge(
                    icon: doc.type.icon,
                    label: doc.type.label,
                    color: doc.type.color,
                  ),
                  const SizedBox(height: kSpace1),
                  DocExtBadge(doc: doc),
                ],
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            doc.title,
            style: kStyleTitle.copyWith(fontSize: 20, height: 1.25),
          ),
        ],
      ),
    );
  }
}

// ── File metadata card ────────────────────────────────────────────────────────

class _FileMetaCard extends StatelessWidget {
  const _FileMetaCard({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
        boxShadow: kShadowSm,
      ),
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        children: [
          WabwayMetaRow(
            icon: Icons.person_outline_rounded,
            label: 'Uploaded by',
            value: _uploaderName(context, doc.uploadedById),
          ),
          _divider(),
          WabwayMetaRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _fmtDateFull(doc.uploadedAt),
          ),
          _divider(),
          WabwayMetaRow(
            icon: Icons.storage_rounded,
            label: 'File size',
            value: doc.formattedSize,
          ),
          if (doc.amount != null) ...[
            _divider(),
            WabwayMetaRow(
              icon: Icons.attach_money_rounded,
              label: 'Amount',
              value: fmtAmount(doc.amount!, doc.currency ?? 'JPY'),
              valueStyle: GoogleFonts.ibmPlexMono(
                fontSize: kTextBase,
                fontWeight: FontWeight.w600,
                color: kColorInk,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: kSpace4, thickness: 1, color: kColorBorder);
}

// ── Linked section ────────────────────────────────────────────────────────────

class _LinkedSection extends StatelessWidget {
  const _LinkedSection({
    required this.links,
    required this.availableSpots,
    required this.tripName,
    required this.linkLoading,
    required this.unlinkingKeys,
    required this.onAddLink,
    required this.onRemoveLink,
  });

  final List<DocumentLink> links;
  final List<Spot> availableSpots;
  final String tripName;
  final bool linkLoading;
  final Set<String> unlinkingKeys;
  final VoidCallback onAddLink;
  final ValueChanged<DocumentLink> onRemoveLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Linked to',
                style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const Spacer(),
            if (linkLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kColorPrimary),
                ),
              )
            else
              GestureDetector(
                onTap: onAddLink,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace1, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 15, color: kColorPrimary),
                      const SizedBox(width: 3),
                      Text(
                        'Add link',
                        style: kStyleCaptionMedium.copyWith(
                            color: kColorPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: kSpace2),
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: kSpace1, bottom: kSpace1),
            child: Text(
              'Not linked to anything yet.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          )
        else
          ...links.map((link) => _LinkedRow(
                link: link,
                availableSpots: availableSpots,
                tripName: tripName,
                isUnlinking: unlinkingKeys.contains(_linkKey(link)),
                onRemove: () => onRemoveLink(link),
              )),
      ],
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({
    required this.link,
    required this.availableSpots,
    required this.tripName,
    required this.isUnlinking,
    required this.onRemove,
  });

  final DocumentLink link;
  final List<Spot> availableSpots;
  final String tripName;
  final bool isUnlinking;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = _linkedLabel(link, availableSpots, tripName);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
              ),
              child: Icon(link.type.icon, size: 16, color: kColorInkSoft),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: kStyleBodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    link.type.label,
                    style: kStyleCaption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            if (isUnlinking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kColorInkSoft),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.link_off_rounded, size: 18),
                color: kColorInkSoft,
                tooltip: 'Remove link',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Link picker sheet ─────────────────────────────────────────────────────────

class _LinkPickerSheet extends StatefulWidget {
  const _LinkPickerSheet({
    required this.tripId,
    required this.tripName,
    required this.availableSpots,
    required this.alreadyLinked,
    required this.onPick,
  });

  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final Set<String> alreadyLinked; // "$type_$linkedId" keys
  final void Function(DocLinkedType type, String linkedId) onPick;

  @override
  State<_LinkPickerSheet> createState() => _LinkPickerSheetState();
}

class _LinkPickerSheetState extends State<_LinkPickerSheet> {
  List<Receipt>? _receipts;
  List<CashWithdrawal>? _withdrawals;
  List<TravelItem>? _travelItems;
  List<TripDay>? _days;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        MoneyService.loadReceipts(widget.tripId),
        MoneyService.loadWithdrawals(widget.tripId),
        TravelService.loadItems(widget.tripId),
        PlanService.loadAll(widget.tripId),
      ]);
      if (!mounted) return;
      setState(() {
        _receipts     = results[0] as List<Receipt>;
        _withdrawals  = results[1] as List<CashWithdrawal>;
        _travelItems  = results[2] as List<TravelItem>;
        _days         = results[3] as List<TripDay>;
        _loading      = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _linked(DocLinkedType type, String id) =>
      widget.alreadyLinked.contains('${type.name}_$id');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          const WabwayDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
            child: Row(
              children: [
                Text('Link to…', style: kStyleTitle),
              ],
            ),
          ),
          const Divider(height: 1, color: kColorBorder),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.only(bottom: kSpace8),
                    children: [
                      // ── Trip ───────────────────────────────────────────
                      if (!_linked(DocLinkedType.trip, widget.tripId)) ...[
                        const _SectionHeader(label: 'Trip'),
                        WabwayActionTile(
                          icon: DocLinkedType.trip.icon,
                          label: widget.tripName,
                          onTap: () => widget.onPick(DocLinkedType.trip, widget.tripId),
                        ),
                      ],

                      // ── Spots ──────────────────────────────────────────
                      ..._buildSection(
                        label: 'Spots',
                        items: widget.availableSpots,
                        linked: (s) => _linked(DocLinkedType.spot, s.id),
                        icon: (_) => DocLinkedType.spot.icon,
                        title: (s) => s.name,
                        subtitle: (s) => '${s.city}, ${s.area}',
                        onTap: (s) => widget.onPick(DocLinkedType.spot, s.id),
                      ),

                      // ── Receipts ───────────────────────────────────────
                      ..._buildSection(
                        label: 'Receipts',
                        items: _receipts ?? [],
                        linked: (r) => _linked(DocLinkedType.receipt, r.id),
                        icon: (_) => DocLinkedType.receipt.icon,
                        title: (r) => r.title,
                        subtitle: (r) => fmtAmount(r.amount, r.currency),
                        onTap: (r) => widget.onPick(DocLinkedType.receipt, r.id),
                      ),

                      // ── Cash withdrawals ────────────────────────────────
                      ..._buildSection(
                        label: 'Cash withdrawals',
                        items: _withdrawals ?? [],
                        linked: (w) => _linked(DocLinkedType.cashWithdrawal, w.id),
                        icon: (_) => DocLinkedType.cashWithdrawal.icon,
                        title: (w) => fmtAmount(w.amount, w.currency),
                        subtitle: (w) => _fmtShortDate(w.date),
                        onTap: (w) => widget.onPick(DocLinkedType.cashWithdrawal, w.id),
                      ),

                      // ── Travel items ────────────────────────────────────
                      ..._buildSection(
                        label: 'Travel',
                        items: _travelItems ?? [],
                        linked: (t) => _linked(DocLinkedType.travelItem, t.id),
                        icon: (_) => DocLinkedType.travelItem.icon,
                        title: (t) => t.title,
                        subtitle: (t) => t.type.label,
                        onTap: (t) => widget.onPick(DocLinkedType.travelItem, t.id),
                      ),

                      // ── Plan days ───────────────────────────────────────
                      if ((_days ?? []).isNotEmpty) ...[
                        const _SectionHeader(label: 'Plan'),
                        for (final day in _days!) ...[
                          // Day itself
                          if (!_linked(DocLinkedType.itineraryDay, day.id))
                            WabwayActionTile(
                              icon: DocLinkedType.itineraryDay.icon,
                              label: 'Day ${day.dayNumber} — ${day.city}',
                              subtitle: _fmtShortDate(day.date),
                              onTap: () => widget.onPick(DocLinkedType.itineraryDay, day.id),
                            ),
                          // Items within the day
                          for (final item in day.items)
                            if (!_linked(DocLinkedType.itineraryItem, item.id))
                              WabwayActionTile(
                                icon: DocLinkedType.itineraryItem.icon,
                                label: item.title,
                                subtitle: 'Day ${day.dayNumber} · ${item.type.label}',
                                onTap: () => widget.onPick(DocLinkedType.itineraryItem, item.id),
                              ),
                        ],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSection<T>({
    required String label,
    required List<T> items,
    required bool Function(T) linked,
    required IconData Function(T) icon,
    required String Function(T) title,
    required String Function(T) subtitle,
    required void Function(T) onTap,
  }) {
    final available = items.where((i) => !linked(i)).toList();
    if (available.isEmpty) return [];
    return [
      _SectionHeader(label: label),
      for (final item in available)
        WabwayActionTile(
          icon: icon(item),
          label: title(item),
          subtitle: subtitle(item),
          onTap: () => onTap(item),
        ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace1),
      child: Text(
        label.toUpperCase(),
        style: kStyleOverline.copyWith(color: kColorInkSoft, letterSpacing: 1),
      ),
    );
  }
}

// ── Image preview ─────────────────────────────────────────────────────────────

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({required this.storagePath});
  final String storagePath;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  String? _url;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final url = await DocService.getSignedUrl(widget.storagePath);
      if (mounted) setState(() { _url = url; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: kRadiusLg,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 320),
        color: kColorSurfaceSunken,
        child: _loading
            ? const SizedBox(
                height: 160,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(kColorPrimary),
                    ),
                  ),
                ),
              )
            : _url != null
                ? Image.network(
                    _url!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 80,
                      child: Center(
                        child: Icon(Icons.broken_image_rounded, color: kColorInkSoft, size: 32),
                      ),
                    ),
                  )
                : const SizedBox(
                    height: 80,
                    child: Center(
                      child: Icon(Icons.broken_image_rounded, color: kColorInkSoft, size: 32),
                    ),
                  ),
      ),
    );
  }
}

// ── Actions section ───────────────────────────────────────────────────────────

class _ActionsSection extends StatefulWidget {
  const _ActionsSection({
    required this.doc,
    required this.tripId,
    this.onDelete,
    this.onRenamed,
    this.onLinkAdded,
  });
  final TripDocument doc;
  final String tripId;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;
  final void Function(DocLinkedType type, String linkedId)? onLinkAdded;

  @override
  State<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<_ActionsSection> {
  bool _openLoading = false;

  Future<void> _openFile() async {
    if (widget.doc.storagePath == null) return;
    setState(() => _openLoading = true);
    try {
      final url = await DocService.getSignedUrl(widget.doc.storagePath!);
      if (!mounted) return;
      if (url == null) {
        _snack('Could not generate link for this file.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack('Could not open file.');
    } finally {
      if (mounted) setState(() => _openLoading = false);
    }
  }

  Future<void> _createReceipt() async {
    final myId = supabase.auth.currentUser?.id ?? '';
    List<TripMember> members;
    try {
      final appMembers = await TripService.loadTripMembers(widget.tripId);
      members = appMembers.isEmpty
          ? [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')]
          : appMembers
              .map((m) => TripMember(
                    id: m.userId,
                    name: m.userId == myId ? 'You' : m.profile.displayName,
                  ))
              .toList();
    } catch (_) {
      members = [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')];
    }
    if (!mounted) return;
    final r = await showAddReceiptSheet(
      context,
      tripId: widget.tripId,
      userId: myId,
      members: members,
    );
    if (r != null && mounted) {
      try {
        await DocService.addLink(
          documentId: widget.doc.id,
          linkedType: DocLinkedType.receipt,
          linkedId: r.id,
          createdBy: myId,
        );
        widget.onLinkAdded?.call(DocLinkedType.receipt, r.id);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Receipt "${r.title}" created',
              style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorSuccess,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _showRenameDialog() async {
    final ctrl = TextEditingController(text: widget.doc.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Rename document', style: kStyleBodySemibold),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Document title',
            hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
          ),
          style: kStyleBody,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Rename', style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final newTitle = ctrl.text.trim();
    if (newTitle.isEmpty || newTitle == widget.doc.title) return;
    try {
      await DocService.renameDocument(widget.doc.id, newTitle);
      widget.onRenamed?.call(newTitle);
      if (mounted) _snack('Renamed to "$newTitle".');
    } catch (_) {
      if (mounted) _snack('Could not rename. Please try again.');
    }
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Delete document?', style: kStyleBodySemibold),
        content: Text(
          'This will permanently remove "${widget.doc.title}" from your trip.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete?.call();
              if (context.mounted) Navigator.maybePop(context);
            },
            child: Text('Delete',
                style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.doc.storagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: [
            WabwayButton(
              label: _openLoading ? 'Opening…' : 'Open',
              icon: Icons.open_in_new_rounded,
              size: WabwayButtonSize.sm,
              loading: _openLoading,
              onPressed: hasFile ? _openFile : null,
            ),
            WabwayButton(
              label: 'Download',
              icon: Icons.download_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: hasFile ? _openFile : null,
            ),
            WabwayButton(
              label: 'Rename',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: _showRenameDialog,
            ),
            WabwayButton(
              label: 'Create Receipt',
              icon: Icons.receipt_long_rounded,
              variant: WabwayButtonVariant.secondary,
              size: WabwayButtonSize.sm,
              onPressed: _createReceipt,
            ),
            WabwayButton(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              variant: WabwayButtonVariant.danger,
              size: WabwayButtonSize.sm,
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Mobile actions bottom sheet ───────────────────────────────────────────────

void _showActionsSheet(
  BuildContext context, {
  required TripDocument doc,
  required String tripId,
  VoidCallback? onDelete,
  ValueChanged<String>? onRenamed,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kColorPaper,
    shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
    builder: (ctx) => _ActionsSheetContent(
      context: context,
      doc: doc,
      tripId: tripId,
      onDelete: onDelete,
      onRenamed: onRenamed,
    ),
  );
}

class _ActionsSheetContent extends StatefulWidget {
  const _ActionsSheetContent({
    required this.context,
    required this.doc,
    required this.tripId,
    this.onDelete,
    this.onRenamed,
  });

  final BuildContext context;
  final TripDocument doc;
  final String tripId;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onRenamed;

  @override
  State<_ActionsSheetContent> createState() => _ActionsSheetContentState();
}

class _ActionsSheetContentState extends State<_ActionsSheetContent> {
  bool _openLoading = false;

  Future<void> _openFile() async {
    if (widget.doc.storagePath == null) return;
    setState(() => _openLoading = true);
    Navigator.pop(context);
    try {
      final url = await DocService.getSignedUrl(widget.doc.storagePath!);
      if (url == null) return;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (mounted) setState(() => _openLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.doc.storagePath != null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WabwayDragHandle(),
          if (hasFile)
            WabwayActionTile(
              icon: Icons.open_in_new_rounded,
              label: _openLoading ? 'Opening…' : 'Open',
              onTap: _openFile,
            ),
          if (hasFile)
            WabwayActionTile(
              icon: Icons.download_rounded,
              label: 'Download',
              onTap: _openFile,
            ),
          WabwayActionTile(
            icon: Icons.edit_rounded,
            label: 'Rename',
            onTap: () async {
              Navigator.pop(context);
              final ctrl = TextEditingController(text: widget.doc.title);
              final confirmed = await showDialog<bool>(
                context: widget.context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: kColorPaper,
                  shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
                  title: Text('Rename document', style: kStyleBodySemibold),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    style: kStyleBody,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => Navigator.pop(ctx, true),
                    decoration: InputDecoration(
                      hintText: 'Document title',
                      hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Rename', style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              final newTitle = ctrl.text.trim();
              if (newTitle.isEmpty || newTitle == widget.doc.title) return;
              try {
                await DocService.renameDocument(widget.doc.id, newTitle);
                widget.onRenamed?.call(newTitle);
              } catch (_) {}
            },
          ),
          WabwayActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'Create Receipt from document',
            onTap: () async {
              Navigator.pop(context);
              final outerCtx = widget.context;
              if (!outerCtx.mounted) return;
              final myId = supabase.auth.currentUser?.id ?? '';
              List<TripMember> members;
              try {
                final appMembers = await TripService.loadTripMembers(widget.tripId);
                members = appMembers.isEmpty
                    ? [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')]
                    : appMembers
                        .map((m) => TripMember(
                              id: m.userId,
                              name: m.userId == myId ? 'You' : m.profile.displayName,
                            ))
                        .toList();
              } catch (_) {
                members = [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')];
              }
              if (!outerCtx.mounted) return;
              final r = await showAddReceiptSheet(outerCtx,
                  tripId: widget.tripId, userId: myId, members: members);
              if (r != null && outerCtx.mounted) {
                try {
                  await DocService.addLink(
                    documentId: widget.doc.id,
                    linkedType: DocLinkedType.receipt,
                    linkedId: r.id,
                    createdBy: myId,
                  );
                } catch (_) {}
                if (outerCtx.mounted) {
                  ScaffoldMessenger.of(outerCtx).showSnackBar(SnackBar(
                    content: Text('Receipt "${r.title}" created',
                        style: kStyleBody.copyWith(color: Colors.white)),
                    backgroundColor: kColorSuccess,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              }
            },
          ),
          WabwayActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: kColorDanger,
            onTap: () {
              Navigator.pop(context);
              widget.onDelete?.call();
              Navigator.maybePop(widget.context);
            },
          ),
          const SizedBox(height: kSpace4),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDateFull(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}
