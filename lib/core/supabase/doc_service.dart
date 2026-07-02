import 'dart:math';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/docs_data.dart';
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

  static String _linkedTypeToDb(DocLinkedType t) => switch (t) {
        DocLinkedType.spot            => 'spot',
        DocLinkedType.travelItem      => 'travel_item',
        DocLinkedType.receipt         => 'receipt',
        DocLinkedType.cashWithdrawal  => 'cash_withdrawal',
        DocLinkedType.itineraryItem   => 'itinerary_item',
        DocLinkedType.itineraryDay    => 'itinerary_day',
        DocLinkedType.trip            => 'trip',
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
      links:        links,
    );
  }

  // ── Queries ──────────────────────────────────────────────────────────────────

  static Future<List<TripDocument>> loadDocuments(String tripId) async {
    final data = await supabase
        .from('documents')
        .select('*, document_links(*)')
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return data.map<TripDocument>((r) => _docFromRow(r)).toList();
  }

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
    }).select('*, document_links(*)').single();
    return _docFromRow(inserted);
  }

  static Future<void> addLink({
    required String documentId,
    required DocLinkedType linkedType,
    required String linkedId,
    required String createdBy,
  }) async {
    await supabase.from('document_links').insert({
      'document_id': documentId,
      'linked_type': _linkedTypeToDb(linkedType),
      'linked_id':   linkedId,
      'created_by':  createdBy,
    });
  }

  static Future<void> deleteLink({
    required String documentId,
    required DocLinkedType linkedType,
    required String linkedId,
  }) async {
    await supabase
        .from('document_links')
        .delete()
        .eq('document_id', documentId)
        .eq('linked_type', _linkedTypeToDb(linkedType))
        .eq('linked_id', linkedId);
  }

  static Future<void> deleteDocument(String docId) async {
    await supabase.from('documents').delete().eq('id', docId);
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
