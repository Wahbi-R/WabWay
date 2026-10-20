import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/money_data.dart';
import 'receipt_scan_service.dart';
import 'supabase/client.dart';
import 'supabase/doc_service.dart';
import 'supabase/money_service.dart';

// ─── Receipts links (receipts.wabble.ca) ──────────────────────────────────────
//
// Receipts is its own product: a split-the-bill site where anyone with the
// link can claim items and mark themselves paid. WabWay publishes a receipt
// there as an ordinary split (via the same wabway-server `/receipt/save` the
// site uses) and can read the link back. WabWay's receipt stays the source of
// truth: claims made on the link are only applied when someone taps "Apply".
//
// Person ids on the link are indexes into Receipt.splitLinkMembers.

const kReceiptsSiteUrl = 'https://receipts.wabble.ca';
const _kSaveUrl = 'https://audio.wabble.ca/receipt/save';

// The Receipts project's public anon key (the same one shipped in the
// Receipts site's bundle) — read-only on receipt_splits, insert-only on the
// receipt-images bucket.
const _kReceiptsSupabaseUrl = String.fromEnvironment(
  'RECEIPTS_SUPABASE_URL',
  defaultValue: 'https://syocailabsljnapwvaox.supabase.co',
);
const _kReceiptsAnonKey = String.fromEnvironment(
  'RECEIPTS_SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5b2NhaWxhYnNsam5hcHd2YW94Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4NzQ1MzcsImV4cCI6MjA5OTQ1MDUzN30.7AdIdZDPexgCJKMl0ma76kRFZFy0UkQDmlIPFYNDyU8',
);

// Same palette as the Receipts site (PERSON_COLORS).
const _kPersonColors = [
  '#EF4444', '#3B82F6', '#10B981', '#F59E0B',
  '#8B5CF6', '#EC4899', '#06B6D4', '#F97316',
  '#84CC16', '#6366F1', '#14B8A6', '#E11D48',
  '#A855F7', '#0EA5E9', '#D97706', '#64748B',
];

String receiptsLinkUrl(String splitId) => '$kReceiptsSiteUrl/?s=$splitId';

/// What's on a Receipts link right now, mapped back onto trip members.
class RemoteSplit {
  const RemoteSplit({
    required this.items,
    required this.paidMemberIds,
    required this.unknownPeople,
    required this.hash,
    required this.raw,
  });

  /// Items and claims, with person ids mapped to member ids.
  final ReceiptItemization items;
  /// Members marked paid on the link.
  final Set<String> paidMemberIds;
  /// Names of people added on the link who aren't trip members — their
  /// claims can't become WabWay shares (the payer covers them).
  final List<String> unknownPeople;
  final String hash;
  final Map<String, dynamic> raw;
}

enum LinkPushResult { pushed, noLink, remoteChanged, failed }

abstract final class ReceiptsLinkService {
  // ── Building the split ─────────────────────────────────────────────────────

  /// The itemization a link is built from: the receipt's own, or a one-line
  /// bill reproducing its amount splits.
  static ReceiptItemization itemsFor(Receipt r) => r.isItemized
      ? r.items!
      : ReceiptItemization.fromSplits(title: r.title, amount: r.amount, splits: r.splits);

  /// Link person order: existing order first, then any new trip members.
  static List<String> memberOrder(Receipt r, List<TripMember> members) => [
        ...r.splitLinkMembers,
        for (final m in members)
          if (!r.splitLinkMembers.contains(m.id)) m.id,
      ];

  static Map<String, dynamic> buildPayload({
    required Receipt receipt,
    required List<TripMember> members,
    required List<String> order,
  }) {
    final items = itemsFor(receipt);
    final index = {for (var i = 0; i < order.length; i++) order[i]: i};
    final byId = {for (final m in members) m.id: m};
    final paid = {
      for (final s in receipt.splits)
        if (s.isSettled && index.containsKey(s.memberId)) '${index[s.memberId]}': true,
      // The payer has paid by definition.
      if (index.containsKey(receipt.paidById)) '${index[receipt.paidById]}': true,
    };
    return {
      'receipt': {
        'title':    receipt.title,
        'items':    [for (final i in items.items) i.toJson()],
        'subtotal': items.itemsTotal,
        'discount': items.discount,
        'tax':      items.tax,
        'tip':      items.tip,
        'total':    items.total,
      },
      'people': [
        for (var i = 0; i < order.length; i++)
          {
            'id':    i,
            'name':  byId[order[i]]?.name ?? 'Member ${i + 1}',
            'color': _kPersonColors[i % _kPersonColors.length],
          },
      ],
      'assignments': {
        for (final e in items.assignments.entries)
          '${e.key}': {
            for (final w in e.value.entries)
              if (index.containsKey(w.key)) '${index[w.key]}': w.value,
          },
      },
      'paid': paid,
    };
  }

  // ── Hash (detects edits made on the link) ──────────────────────────────────

  /// FNV-1a over a canonical form of what both apps can change: items,
  /// tax/tip/discount, claims and paid flags. Stable across Postgres jsonb
  /// key reordering and int/double formatting.
  static String hashOf(Map<String, dynamic> split) {
    final receipt = Map<String, dynamic>.from((split['receipt'] as Map?) ?? const {});
    final items = [
      for (final i in (receipt['items'] as List?) ?? const [])
        [
          (i as Map)['id'],
          '${i['name']}'.trim(),
          _num(i['quantity']),
          _num(i['total_price']),
        ],
    ];
    final assignments = <String, Map<String, String>>{};
    ((split['assignments'] as Map?) ?? const {}).forEach((k, v) {
      final w = <String, String>{
        for (final e in (v as Map).entries)
          if (e.value is num && (e.value as num) > 0) '${e.key}': _num(e.value),
      };
      if (w.isNotEmpty) assignments['$k'] = w;
    });
    final paid = [
      for (final e in ((split['paid'] as Map?) ?? const {}).entries)
        if (e.value == true) '${e.key}',
    ]..sort();
    final canonical = _canon({
      'items': items,
      'tax': _num(receipt['tax']),
      'tip': _num(receipt['tip']),
      'discount': _num(receipt['discount']),
      'assignments': assignments,
      'paid': paid,
    });
    var h = 0x811c9dc5;
    for (final b in utf8.encode(canonical)) {
      h ^= b;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  static String _num(Object? v) => ((v as num?) ?? 0).toDouble().toStringAsFixed(4);

  static String _canon(Object? v) {
    if (v is Map) {
      final keys = v.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:${_canon(v[k])}').join(',')}}';
    }
    if (v is List) return '[${v.map(_canon).join(',')}]';
    return jsonEncode(v);
  }

  // ── Network ────────────────────────────────────────────────────────────────

  static Future<String> _save(Map<String, dynamic> payload, {String? splitId}) async {
    final res = await http
        .post(
          Uri.parse(_kSaveUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...payload,
            'approvals': payload['approvals'] ?? const {},
            'history': payload['history'] ?? const [],
            if (splitId != null) 'split_id': splitId,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Receipts save failed (${res.statusCode})');
    }
    return (jsonDecode(res.body) as Map)['id'] as String;
  }

  static Future<Map<String, dynamic>?> _fetchRaw(String splitId) async {
    final res = await http.get(
      Uri.parse('$_kReceiptsSupabaseUrl/rest/v1/receipt_splits'
          '?id=eq.${Uri.encodeQueryComponent(splitId)}'
          '&select=receipt,people,assignments,paid,approvals,history'),
      headers: {'apikey': _kReceiptsAnonKey, 'Authorization': 'Bearer $_kReceiptsAnonKey'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('Receipts fetch failed (${res.statusCode})');
    final rows = jsonDecode(res.body) as List;
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }

  /// Upload photos so people opening the link can check the bill.
  /// Best-effort: returns how many failed.
  static Future<int> uploadPhotos(String splitId, List<ScanImage> photos) async {
    var failed = 0;
    for (var i = 0; i < photos.length; i++) {
      final p = photos[i];
      if (!p.isScannable) { failed++; continue; }
      final ext = p.ext.toLowerCase() == 'jpeg' ? 'jpg' : p.ext.toLowerCase();
      try {
        final res = await http.post(
          Uri.parse('$_kReceiptsSupabaseUrl/storage/v1/object/receipt-images/$splitId/$i.$ext'),
          headers: {
            'apikey': _kReceiptsAnonKey,
            'Authorization': 'Bearer $_kReceiptsAnonKey',
            'Content-Type': p.mediaType,
          },
          body: p.bytes,
        ).timeout(const Duration(seconds: 30));
        if (res.statusCode >= 300) failed++;
      } catch (_) {
        failed++;
      }
    }
    return failed;
  }

  /// The receipt's attached photos (for a link created after saving).
  /// Best-effort: skips anything it can't download.
  static Future<List<ScanImage>> attachedPhotos(String receiptId) async {
    final out = <ScanImage>[];
    try {
      final docs = await DocService.loadAttached(receiptId);
      for (final d in docs) {
        final ext = d.ext.toLowerCase();
        if (d.storagePath == null || !const {'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) continue;
        final url = await DocService.getSignedUrl(d.storagePath!);
        if (url == null) continue;
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
        if (res.statusCode == 200) out.add(ScanImage(res.bodyBytes, ext));
      }
    } catch (_) {}
    return out;
  }

  // ── Reading a link back ────────────────────────────────────────────────────

  static RemoteSplit parseRemote(Map<String, dynamic> raw, Receipt receipt, List<TripMember> members) {
    final order = receipt.splitLinkMembers;
    final people = ((raw['people'] as List?) ?? const [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    // person id → member id: by link order, then by name for people added on the site.
    final byName = {for (final m in members) m.name.trim().toLowerCase(): m.id};
    final personToMember = <String, String>{};
    final unknown = <String>[];
    for (final p in people) {
      final pid = (p['id'] as num).toInt();
      final name = '${p['name'] ?? ''}';
      final member = pid >= 0 && pid < order.length ? order[pid] : byName[name.trim().toLowerCase()];
      if (member != null && !personToMember.containsValue(member)) {
        personToMember['$pid'] = member;
      } else {
        unknown.add(name);
      }
    }
    final remoteReceipt = Map<String, dynamic>.from((raw['receipt'] as Map?) ?? const {});
    final mapped = ReceiptItemization.fromJsonOrNull({
          ...remoteReceipt,
          'total': (remoteReceipt['total'] as num?) ?? 0,
          'assignments': {
            for (final e in ((raw['assignments'] as Map?) ?? const {}).entries)
              '${e.key}': {
                for (final w in (e.value as Map).entries)
                  if (personToMember.containsKey('${w.key}')) personToMember['${w.key}']!: w.value,
              },
          },
        }) ??
        ReceiptItemization.empty;
    return RemoteSplit(
      items: mapped.copyWith(title: receipt.items?.title),
      paidMemberIds: {
        for (final e in ((raw['paid'] as Map?) ?? const {}).entries)
          if (e.value == true && personToMember.containsKey('${e.key}')) personToMember['${e.key}']!,
      },
      unknownPeople: unknown,
      hash: hashOf(raw),
      raw: raw,
    );
  }

  static Future<RemoteSplit?> fetch(Receipt receipt, List<TripMember> members) async {
    final id = receipt.splitLinkId;
    if (id == null) return null;
    final raw = await _fetchRaw(id);
    return raw == null ? null : parseRemote(raw, receipt, members);
  }

  // ── Orchestration ──────────────────────────────────────────────────────────

  static Future<void> _store(Receipt r, String linkId, List<String> order, String hash) =>
      supabase.rpc('set_receipt_split_link', params: {
        'p_receipt_id': r.id,
        'p_link_id':    linkId,
        'p_members':    order,
        'p_hash':       hash,
      });

  /// Publish [receipt] as a new Receipts link (no-op if it has one). Returns
  /// the receipt with its link fields set. Throws when offline.
  static Future<Receipt> create(
    Receipt receipt,
    List<TripMember> members, {
    List<ScanImage> photos = const [],
  }) async {
    if (receipt.splitLinkId != null) return receipt;
    final order = memberOrder(receipt, members);
    final payload = buildPayload(receipt: receipt, members: members, order: order);
    final id = await _save({
      ...payload,
      'history': [
        {'ts': DateTime.now().toUtc().toIso8601String(), 'msg': 'Shared from WabWay'},
      ],
    });
    final hash = hashOf(payload);
    await _store(receipt, id, order, hash);
    if (photos.isNotEmpty) unawaited(uploadPhotos(id, photos));
    return receipt.copyWith(splitLinkId: id, splitLinkMembers: order, splitLinkHash: hash);
  }

  /// After a WabWay edit: write the receipt to its link — unless someone
  /// changed the link since WabWay last synced, in which case nothing is
  /// overwritten and the detail screen offers to apply their changes.
  static Future<(LinkPushResult, Receipt)> push(Receipt receipt, List<TripMember> members) async {
    final id = receipt.splitLinkId;
    if (id == null) return (LinkPushResult.noLink, receipt);
    try {
      final raw = await _fetchRaw(id);
      if (raw != null && receipt.splitLinkHash != null && hashOf(raw) != receipt.splitLinkHash) {
        return (LinkPushResult.remoteChanged, receipt);
      }
      return (LinkPushResult.pushed, await _overwrite(receipt, members, raw, 'Updated from WabWay'));
    } catch (_) {
      return (LinkPushResult.failed, receipt);
    }
  }

  /// Overwrite the link with WabWay's version (discarding changes made there).
  static Future<Receipt> overwrite(Receipt receipt, List<TripMember> members) async {
    final raw = receipt.splitLinkId == null ? null : await _fetchRaw(receipt.splitLinkId!);
    return _overwrite(receipt, members, raw, 'Updated from WabWay');
  }

  static Future<Receipt> _overwrite(
    Receipt receipt,
    List<TripMember> members,
    Map<String, dynamic>? raw,
    String historyMsg,
  ) async {
    final order = memberOrder(receipt, members);
    final payload = buildPayload(receipt: receipt, members: members, order: order);
    // Keep the link's own approvals and history; people added on the site
    // stay listed so their claims don't vanish from the link.
    final remotePeople = ((raw?['people'] as List?) ?? const [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .where((p) => (p['id'] as num).toInt() >= order.length)
        .toList();
    final id = await _save({
      ...payload,
      'people': [...payload['people'] as List, ...remotePeople],
      'approvals': raw?['approvals'] ?? const {},
      'history': [
        ...((raw?['history'] as List?) ?? const []),
        {'ts': DateTime.now().toUtc().toIso8601String(), 'msg': historyMsg},
      ],
    }, splitId: receipt.splitLinkId);
    final hash = hashOf(payload);
    await _store(receipt, id, order, hash);
    return receipt.copyWith(splitLinkId: id, splitLinkMembers: order, splitLinkHash: hash);
  }

  /// Apply the link's items, claims and paid flags to the WabWay receipt.
  /// Only the payer / creator / trip owner can change the split (RLS); anyone
  /// can have their own share marked paid.
  static Future<Receipt> apply(
    Receipt receipt,
    RemoteSplit remote,
    List<TripMember> members,
  ) async {
    var updated = receipt;
    final ids = members.map((m) => m.id);
    final splits = remote.items.toSplits(ids, receipt.currency);
    final changedSplit = !_sameSplits(splits, receipt.splits) ||
        jsonEncode(remote.items.toJson()) != jsonEncode(itemsFor(receipt).toJson());
    if (changedSplit) {
      updated = await MoneyService.updateItemsAndSplits(receipt, remote.items, splits);
    }
    for (final s in updated.splits) {
      if (!s.isSettled && s.memberId != receipt.paidById && remote.paidMemberIds.contains(s.memberId)) {
        await MoneyService.setShareSettled(
            receiptId: receipt.id, memberId: s.memberId, settled: true);
      }
    }
    final order = memberOrder(receipt, members);
    await _store(receipt, receipt.splitLinkId!, order, remote.hash);
    final settled = remote.paidMemberIds;
    return updated.copyWith(
      splits: [
        for (final s in updated.splits)
          settled.contains(s.memberId) && s.memberId != receipt.paidById && !s.isSettled
              ? s.copyWith(isSettled: true, settledAt: DateTime.now())
              : s,
      ],
      splitLinkMembers: order,
      splitLinkHash: remote.hash,
    );
  }

  static bool _sameSplits(List<ReceiptSplit> a, List<ReceiptSplit> b) {
    final ma = {for (final s in a) s.memberId: s.amount};
    final mb = {for (final s in b) s.memberId: s.amount};
    if (ma.length != mb.length) return false;
    return ma.entries.every((e) => mb[e.key] != null && (mb[e.key]! - e.value).abs() < 0.005);
  }
}
