import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/places/listing_parser.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../data/accommodation_data.dart' show Accommodation;
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/share_data.dart';
import '../../data/spot_data.dart';
import '../../widgets/widgets.dart';
import '../accommodations/add_accommodation_sheet.dart';
import '../docs/add_doc_sheet.dart';
import '../links/add_link_sheet.dart';
import '../money/add_receipt_sheet.dart';
import '../plan/add_item_sheet.dart';
import '../plan/day_picker_sheet.dart';
import '../spots/add_spot_sheet.dart';
import '../travel/add_travel_sheet.dart';

/// Opens the ONE Add sheet for [dest] (optionally pre-filled) and persists the
/// result for draft-returning sheets. Returns true when something was created.
///
/// Shared by Import ("Continue") and Home's quick-add — never rebuild an
/// entity form or its save mapping elsewhere.
///
/// [uploadFile] (Import only) uploads the shared file as a document right
/// before a travel/plan sheet opens, so its doc picker shows it pre-selected;
/// the document is deleted again if the sheet is cancelled.
Future<bool> openAddSheet(
  BuildContext context,
  WidgetRef ref,
  ShareDestination dest, {
  ImportPrefill? prefill,
  String? sourceUrl,
  Future<TripDocument?> Function()? uploadFile,
}) async {
  final trip = ref.read(activeTripProvider);
  final tripId = trip?.id ?? '';
  final userId = ref.read(profileProvider)?.id ?? '';
  if (tripId.isEmpty || userId.isEmpty) return false;
  final pre = prefill ?? const ImportPrefill();

  Future<void> discard(TripDocument? doc) async {
    if (doc == null) return;
    try {
      await DocService.deleteDocument(doc.id);
    } catch (_) {}
  }

  switch (dest) {
    case ShareDestination.spot:
      return await showAddSpotSheet(context, tripId: tripId, userId: userId, prefill: pre) != null;

    case ShareDestination.link:
      return await showAddLinkSheet(context,
              tripId: tripId, userId: userId,
              prefillUrl: sourceUrl, prefillTitle: pre.title) !=
          null;

    case ShareDestination.stay:
      final listing = sourceUrl == null ? null : await ListingParser.parse(sourceUrl);
      if (!context.mounted) return false;
      return await showAddStaySheet(context,
              tripId: tripId, userId: userId,
              prefilled: listing, initialUrl: sourceUrl) !=
          null;

    case ShareDestination.document:
      return await showAddDocSheet(context,
              tripId: tripId,
              tripName: trip?.name ?? '',
              userId: userId,
              availableSpots: const [],
              prefill: pre) !=
          null;

    case ShareDestination.receipt:
      final members = ref
          .read(tripMembersProvider)
          .map((m) => TripMember(id: m.userId, name: m.profile.displayName))
          .toList();
      return await showAddReceiptSheet(context,
              tripId: tripId,
              userId: userId,
              members: members,
              homeCurrency: trip?.homeCurrency ?? 'CAD',
              defaultCurrency: trip?.defaultCurrency,
              prefill: pre) !=
          null;

    case ShareDestination.travelItem:
      final doc = await uploadFile?.call();
      final docs = await DocService.loadDocuments(tripId).catchError((_) => <TripDocument>[]);
      if (!context.mounted) return false;
      final draft = await showAddTravelSheet(context,
          docs: docs, prefill: pre.withDocIds([if (doc != null) doc.id]));
      if (draft == null) {
        await discard(doc);
        return false;
      }
      await TravelService.createFromDraft(draft, tripId: tripId, createdBy: userId);
      return true;

    case ShareDestination.planItem:
      final days = await PlanService.loadAll(tripId);
      if (!context.mounted) return false;
      if (days.isEmpty) {
        showWabwaySnack(context, 'Set your trip dates in Trip settings to start planning days.');
        return false;
      }
      final picked = await showDayPickerSheet(context, days: days);
      if (picked == null || !context.mounted) return false;
      final day = days.firstWhere((d) => d.id == picked.$1);
      final doc = await uploadFile?.call();
      final lists = await Future.wait<List<Object>>([
        SpotService.loadSpots(tripId).catchError((_) => <Spot>[]),
        DocService.loadDocuments(tripId).catchError((_) => <TripDocument>[]),
        AccommodationService.loadAll(tripId).catchError((_) => <Accommodation>[]),
      ]);
      if (!context.mounted) return false;
      final draft = await showAddItemSheet(context,
          dayId: day.id,
          defaultCurrency: trip?.defaultCurrency ?? 'CAD',
          spots: lists[0].cast<Spot>(),
          docs: lists[1].cast<TripDocument>(),
          stays: lists[2].cast<Accommodation>(),
          prefill: pre.withDocIds([if (doc != null) doc.id]));
      if (draft == null) {
        await discard(doc);
        return false;
      }
      await PlanService.createItemFromDraft(draft,
          tripId: tripId, dayId: day.id, createdBy: userId, sortOrder: day.items.length);
      return true;
  }
}

/// Home's "+": a quick-add menu for every entity, each opening its ONE Add
/// sheet. Returns the destination that was created, or null.
Future<ShareDestination?> showQuickAddMenu(BuildContext context, WidgetRef ref) async {
  const order = [
    ShareDestination.spot,
    ShareDestination.planItem,
    ShareDestination.receipt,
    ShareDestination.travelItem,
    ShareDestination.stay,
    ShareDestination.link,
    ShareDestination.document,
  ];
  final dest = await showWabwayAutoSheet<ShareDestination>(
    context,
    builder: (ctx, handle) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (handle) const WabwayDragHandle(),
          for (final d in order)
            WabwayActionTile(
              icon: d.icon,
              label: 'Add ${d.label.toLowerCase()}',
              subtitle: d.description,
              onTap: () => Navigator.pop(ctx, d),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (dest == null || !context.mounted) return null;
  final created = await openAddSheet(context, ref, dest);
  return created ? dest : null;
}
