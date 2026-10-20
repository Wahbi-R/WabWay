import '../data/connection_data.dart';
import '../data/docs_data.dart';
import '../data/money_data.dart';
import 'receipt_scan_service.dart';
import 'receipts_link_service.dart';
import 'supabase/doc_service.dart';
import 'sync_queue.dart';

/// What happened after a receipt was saved.
class ReceiptFollowupResult {
  const ReceiptFollowupResult(this.receipt, {this.docsFailed = false, this.linkQueued = false});
  final Receipt receipt;
  final bool docsFailed;
  /// The Receipts link couldn't be created now and will be retried.
  final bool linkQueued;
}

/// Everything that happens after a receipt row is saved — shared by the Add
/// Receipt form and the offline queue so both behave the same:
/// photos become Receipt documents attached to it, picked documents are
/// attached, and (if asked) a Receipts link is published, or queued for
/// later when that fails.
Future<ReceiptFollowupResult> runReceiptFollowups({
  required String tripId,
  required String userId,
  required Receipt receipt,
  required List<TripMember> members,
  List<ScanImage> photos = const [],
  Iterable<String> docIds = const [],
  bool createLink = false,
}) async {
  var docsFailed = false;
  for (var i = 0; i < photos.length; i++) {
    final p = photos[i];
    try {
      final doc = await DocService.uploadAndCreate(
        tripId:     tripId,
        userId:     userId,
        title:      photos.length > 1 ? '${receipt.title} (${i + 1})' : receipt.title,
        type:       DocType.receipt,
        ext:        p.ext,
        bytes:      p.bytes,
        fileSizeKb: (p.bytes.lengthInBytes / 1024).round(),
      );
      await DocService.attach(
        tripId: tripId, userId: userId, docIds: [doc.id],
        entityType: EntityType.receipt, entityId: receipt.id,
      );
    } catch (_) {
      docsFailed = true;
    }
  }
  if (docIds.isNotEmpty) {
    try {
      await DocService.attach(
        tripId: tripId, userId: userId, docIds: docIds,
        entityType: EntityType.receipt, entityId: receipt.id,
      );
    } catch (_) {
      docsFailed = true;
    }
  }
  var updated = receipt;
  var linkQueued = false;
  if (createLink && receipt.splitLinkId == null) {
    try {
      updated = await ReceiptsLinkService.create(receipt, members, photos: photos);
    } catch (_) {
      await SyncQueue.enqueueLink(tripId, receipt.id);
      linkQueued = true;
    }
  }
  return ReceiptFollowupResult(updated, docsFailed: docsFailed, linkQueued: linkQueued);
}
