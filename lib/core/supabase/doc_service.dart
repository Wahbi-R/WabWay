import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/connection_data.dart';
import '../../data/docs_data.dart';
import '../offline_cache.dart';
import 'client.dart';

abstract final class DocService {
  // ── Enum converters ──────────────────────────────────────────────────────────

  static DocType _typeFrom(String s) => switch (s) {
        'flight'      => DocType.flight,
        'hotel'       => DocType.hotel,
        'train'       => DocType.train,
        'ticket'      => DocType.ticket,
        'reservation' => DocType.reservation,
        'receipt'     => DocType.receipt,
        'insurance'   => DocType.insurance,
        'form'        => DocType.form,
        'screenshot'  => DocType.screenshot,
        _             => DocType.other,
      };

  static String _typeToDb(DocType t) => switch (t) {
        DocType.flight      => 'flight',
        DocType.hotel       => 'hotel',
        DocType.train       => 'train',
        DocType.ticket      => 'ticket',
        DocType.reservation => 'reservation',
        DocType.receipt     => 'receipt',
        DocType.insurance   => 'insurance',
        DocType.form        => 'form',
        DocType.screenshot  => 'screenshot',
        DocType.other       => 'other',
      };

  static DocLinkedType _linkedTypeFrom(String s) => switch (s) {
        'spot'            => DocLinkedType.spot,
        'travel_item'     => DocLinkedType.travelItem,
        'receipt'         => DocLinkedType.receipt,
        'cash_withdrawal' => DocLinkedType.cashWithdrawal,
        'itinerary_item'  => DocLinkedType.itineraryItem,
        'itinerary_day'   => DocLinkedType.itineraryDay,
        _                 => DocLinkedType.trip,
      };

  // ── Row → model ──────────────────────────────────────────────────────────────

  static TripDocument _docFromRow(Map<String, dynamic> row) {
    final linksRaw = row['document_links'] as List? ?? [];
    final links = linksRaw.map((l) {
      final link = l as Map<String, dynamic>;
      return DocumentLink(
        type:     _linkedTypeFrom(link['linked_type'] as String),
        linkedId: link['linked_id'] as String,
      );
    }).toList();

    return TripDocument(
      id:           row['id'] as String,
      title:        row['title'] as String,
      type:         _typeFrom(row['type'] as String),
      ext:          row['ext'] as String,
      storagePath:  row['storage_path'] as String?,
      uploadedById: row['uploaded_by'] as String,
      uploadedAt:   DateTime.parse(row['created_at'] as String),
      fileSizeKb:   row['file_size_kb'] as int?,
      amount:       (row['amount'] as num?)?.toDouble(),
      currency:     row['currency'] as String?,
      notes:        row['notes'] as String?,
      url:          row['url'] as String?,
      links:        links,
    );
  }

  // ── Queries ──────────────────────────────────────────────────────────────────

  static Future<List<TripDocument>> loadDocuments(String tripId) async {
    final data = await supabase
        .from('documents')
        .select('*, document_links(*)')
        .eq('trip_id', tripId)
        .isFilter('link_category', null)
        .order('created_at', ascending: false);
    await OfflineCache.write(OfflineCache.docsKey(tripId), data);
    final docs = data.map<TripDocument>((r) => _docFromRow(r)).toList();
    // Attachment counts for the cards: trip_connections + legacy links.
    try {
      final counts = await attachedPeerCounts(tripId, docs);
      return [
        for (final d in docs)
          TripDocument(
            id: d.id, title: d.title, type: d.type, ext: d.ext,
            uploadedById: d.uploadedById, uploadedAt: d.uploadedAt,
            storagePath: d.storagePath, fileSizeKb: d.fileSizeKb,
            amount: d.amount, currency: d.currency, notes: d.notes,
            url: d.url, links: d.links, connectedCount: counts[d.id] ?? 0,
          ),
      ];
    } catch (_) {
      return docs;
    }
  }

  static Future<List<TripDocument>?> loadDocumentsFromCache(String tripId) =>
      OfflineCache.read(
        OfflineCache.docsKey(tripId),
        (json) => (json as List)
            .map((r) => _docFromRow(r as Map<String, dynamic>))
            .toList(),
      );

  static Future<TripDocument> createDocument({
    required String tripId,
    required String userId,
    required String title,
    required DocType type,
    required String ext,
    String? storagePath,
    int? fileSizeKb,
    double? amount,
    String? currency,
    String? notes,
    String? url,
  }) async {
    final inserted = await supabase.from('documents').insert({
      'trip_id':     tripId,
      'uploaded_by': userId,
      'title':       title.trim(),
      'type':        _typeToDb(type),
      'ext':         ext.toLowerCase(),
      if (storagePath != null) 'storage_path': storagePath,
      if (fileSizeKb  != null) 'file_size_kb':  fileSizeKb,
      if (amount      != null) 'amount':         amount,
      if (currency    != null && currency.isNotEmpty) 'currency': currency.toUpperCase(),
      if (notes       != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (url         != null && url.trim().isNotEmpty) 'url': url.trim(),
    }).select('*, document_links(*)').single();
    return _docFromRow(inserted);
  }

  // ── Attachments (a document attached to a spot / travel / stay / plan item /
  // receipt / cash withdrawal) ────────────────────────────────────────────────
  //
  // Since build 418 every attachment is a `trip_connections` row (doc ↔ entity).
  // Legacy `document_links` rows (copied in migration 047, possibly still
  // written by older installed builds) are read alongside and removed on
  // [detach], but never written.

  /// entityId → attached document ids, for many entities in one go
  /// (list badges such as "2 docs").
  static Future<Map<String, List<String>>> attachedDocIds(
      List<String> entityIds) async {
    final out = <String, Set<String>>{};
    if (entityIds.isEmpty) return {};
    const chunkSize = 50;
    final futures = <Future<void>>[];
    for (var i = 0; i < entityIds.length; i += chunkSize) {
      final chunk = entityIds.sublist(i, min(i + chunkSize, entityIds.length));
      final ids = chunk.toSet();
      final inList = chunk.join(',');
      futures.add(supabase
          .from('trip_connections')
          .select('entity_a_id, entity_a_type, entity_b_id, entity_b_type')
          .or('entity_a_id.in.($inList),entity_b_id.in.($inList)')
          .then((rows) {
        for (final r in rows) {
          if (r['entity_a_type'] == 'doc' && ids.contains(r['entity_b_id'])) {
            (out[r['entity_b_id'] as String] ??= {}).add(r['entity_a_id'] as String);
          } else if (r['entity_b_type'] == 'doc' && ids.contains(r['entity_a_id'])) {
            (out[r['entity_a_id'] as String] ??= {}).add(r['entity_b_id'] as String);
          }
        }
      }));
      futures.add(supabase
          .from('document_links')
          .select('linked_id, document_id')
          .inFilter('linked_id', chunk)
          .then((rows) {
        for (final r in rows) {
          (out[r['linked_id'] as String] ??= {}).add(r['document_id'] as String);
        }
      }));
    }
    await Future.wait(futures);
    return {for (final e in out.entries) e.key: e.value.toList()};
  }

  /// docId → number of distinct items it's attached to, across
  /// trip_connections and the legacy links already on [docs].
  static Future<Map<String, int>> attachedPeerCounts(
      String tripId, List<TripDocument> docs) async {
    final rows = await supabase
        .from('trip_connections')
        .select('entity_a_id, entity_a_type, entity_b_id, entity_b_type')
        .eq('trip_id', tripId)
        .or('entity_a_type.eq.doc,entity_b_type.eq.doc');
    final peers = <String, Set<String>>{
      for (final d in docs)
        d.id: {
          for (final l in d.links)
            if (l.type != DocLinkedType.trip &&
                l.type != DocLinkedType.itineraryDay)
              l.linkedId,
        },
    };
    for (final r in rows) {
      if (r['entity_a_type'] == 'doc') {
        peers[r['entity_a_id'] as String]?.add(r['entity_b_id'] as String);
      }
      if (r['entity_b_type'] == 'doc') {
        peers[r['entity_b_id'] as String]?.add(r['entity_a_id'] as String);
      }
    }
    return {for (final e in peers.entries) e.key: e.value.length};
  }

  /// Documents attached to [entityId], oldest first.
  static Future<List<TripDocument>> loadAttached(String entityId) async {
    final ids = (await attachedDocIds([entityId]))[entityId] ?? const [];
    if (ids.isEmpty) return [];
    final docs = await supabase
        .from('documents')
        .select('*, document_links(*)')
        .inFilter('id', ids)
        .order('created_at');
    return docs.map<TripDocument>((r) => _docFromRow(r)).toList();
  }

  /// Attach [docIds] to an entity. Already-attached ids are skipped.
  static Future<void> attach({
    required String tripId,
    required String userId,
    required Iterable<String> docIds,
    required EntityType entityType,
    required String entityId,
  }) async {
    final existing =
        ((await attachedDocIds([entityId]))[entityId] ?? const []).toSet();
    final toAdd = docIds.toSet().difference(existing);
    if (toAdd.isEmpty) return;
    await supabase.from('trip_connections').upsert(
      [
        for (final id in toAdd)
          {
            'trip_id':       tripId,
            'created_by':    userId,
            'entity_a_type': EntityType.doc.dbValue,
            'entity_a_id':   id,
            'entity_b_type': entityType.dbValue,
            'entity_b_id':   entityId,
          },
      ],
      onConflict: 'entity_a_id,entity_b_id',
      ignoreDuplicates: true,
    );
  }

  /// Detach a document from an entity (both tables, either direction).
  /// The document itself is kept.
  static Future<void> detach({
    required String docId,
    required String entityId,
  }) async {
    await Future.wait([
      supabase.from('trip_connections').delete()
          .eq('entity_a_id', docId).eq('entity_b_id', entityId),
      supabase.from('trip_connections').delete()
          .eq('entity_a_id', entityId).eq('entity_b_id', docId),
      supabase.from('document_links').delete()
          .eq('document_id', docId).eq('linked_id', entityId),
    ]);
  }

  static Future<void> renameDocument(String docId, String newTitle) async {
    final rows = await supabase
        .from('documents')
        .update({'title': newTitle.trim()})
        .eq('id', docId)
        .select();
    if (rows.isEmpty) throw Exception('Could not rename document');
  }

  static Future<void> deleteDocument(String docId) async {
    final rows = await supabase
        .from('documents')
        .delete()
        .eq('id', docId)
        .select();
    if (rows.isEmpty) throw Exception('Could not delete document');
    // trip_connections is polymorphic (no FK cascade) — drop this doc's
    // attachments so they don't linger as phantom "1 doc" counts.
    try {
      await supabase
          .from('trip_connections')
          .delete()
          .or('entity_a_id.eq.$docId,entity_b_id.eq.$docId');
    } catch (_) {}
  }

  // ── File upload + document creation (safe ordered flow) ─────────────────────
  //
  // Order matters:
  //   1. Generate a UUID in the app so the storage path and DB row share the same ID.
  //   2. Upload the file first — if this fails, nothing is written to the DB.
  //   3. Insert the documents row using that UUID as the explicit `id` and the
  //      computed storage_path. If this fails, attempt to delete the orphaned
  //      storage object before rethrowing.
  //   4. Insert document_links rows (called separately by the caller after this
  //      method returns successfully).
  //
  // This avoids the scenario where a document row exists in the DB with no file,
  // or a file exists in storage with no corresponding document row.

  static Future<TripDocument> uploadAndCreate({
    required String tripId,
    required String userId,
    required String title,
    required DocType type,
    required String ext,
    required Uint8List bytes,
    int? fileSizeKb,
    double? amount,
    String? currency,
    String? notes,
    String? url,
  }) async {
    // 1. Generate UUID — shared between storage path and the DB row's primary key.
    final docId = _generateUuid();
    final path = '$tripId/$docId.${ext.toLowerCase()}';

    // 2. Upload first. If this throws, no DB row is created.
    await supabase.storage.from(_bucket).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: _contentType(ext)),
    );

    // 3. Insert the row with the pre-generated UUID and storage_path.
    //    On failure, clean up the orphaned storage object before rethrowing.
    try {
      final inserted = await supabase.from('documents').insert({
        'id':          docId,
        'trip_id':     tripId,
        'uploaded_by': userId,
        'title':       title.trim(),
        'type':        _typeToDb(type),
        'ext':         ext.toLowerCase(),
        'storage_path': path,
        if (fileSizeKb != null) 'file_size_kb': fileSizeKb,
        if (amount     != null) 'amount':        amount,
        if (currency   != null && currency.isNotEmpty) 'currency': currency.toUpperCase(),
        if (notes      != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (url        != null && url.trim().isNotEmpty) 'url': url.trim(),
      }).select('*, document_links(*)').single();
      return _docFromRow(inserted);
    } catch (e) {
      // Best-effort cleanup — swallow secondary errors so the original rethrows.
      try { await supabase.storage.from(_bucket).remove([path]); } catch (_) {}
      rethrow;
    }
  }

  // ── Storage helpers ───────────────────────────────────────────────────────────

  static const _bucket = 'trip-documents';

  static Future<String?> getSignedUrl(String path, {int expiresIn = 3600}) async {
    return supabase.storage.from(_bucket).createSignedUrl(path, expiresIn);
  }

  static final Map<String, (Future<String?>, DateTime)> _thumbCache = {};
  static const _thumbTtl = Duration(minutes: 55);

  static const _imageExts = {'jpg', 'jpeg', 'png', 'webp'};

  static Future<String?> getThumbnailUrl(String storagePath, String ext) {
    if (!_imageExts.contains(ext.toLowerCase())) return Future.value(null);
    final cached = _thumbCache[storagePath];
    if (cached != null && DateTime.now().isBefore(cached.$2)) return cached.$1;
    final future = Future<String?>(() async {
      try {
        return await supabase.storage.from(_bucket).createSignedUrl(
          storagePath,
          3600,
          transform: const TransformOptions(
            width: 400,
            height: 280,
            resize: ResizeMode.cover,
          ),
        );
      } catch (_) {
        return null;
      }
    });
    _thumbCache[storagePath] = (future, DateTime.now().add(_thumbTtl));
    return future;
  }

  static Future<void> deleteStorageFile(String path) async {
    await supabase.storage.from(_bucket).remove([path]);
  }

  // ── Private helpers ───────────────────────────────────────────────────────────

  // RFC 4122 UUID v4 — generated client-side so storage path and DB id match.
  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  static String _contentType(String ext) => switch (ext.toLowerCase()) {
        'pdf'           => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png'           => 'image/png',
        'gif'           => 'image/gif',
        'webp'          => 'image/webp',
        'docx'          => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xlsx'          => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        _               => 'application/octet-stream',
      };
}
