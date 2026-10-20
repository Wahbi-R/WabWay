import '../data/accommodation_data.dart';
import '../data/plan_data.dart';
import '../data/travel_data.dart';
import 'ocr/parsed_booking.dart';
import 'text_utils.dart';

// "Read booking" must not add the same booking twice (re-shared email, the
// PDF of something an assistant already added, a friend sharing the same
// confirmation). These find the existing item and fill in what it's missing.

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

bool _sameRef(String? a, String? b) =>
    a != null && b != null && a.trim().isNotEmpty &&
    a.replaceAll(' ', '').toLowerCase() == b.replaceAll(' ', '').toLowerCase();

bool _sameText(String? a, String? b) =>
    a != null && b != null && foldForSearch(a.trim()) == foldForSearch(b.trim());

/// The item already in the trip that [booking] describes, or null.
/// Same confirmation number (and day, when both have one), else same type,
/// day and departure time, else same title on the same day.
Object? findExistingBooking(
  ParsedBooking booking, {
  required List<TravelItem> travel,
  required List<Accommodation> stays,
  required List<TripDay> days,
}) {
  switch (booking) {
    case ParsedTravel(:final item):
      bool dayOk(TravelItem e) => item.date == null || e.date == null || _sameDay(e.date, item.date);
      return travel.where((e) => _sameRef(e.confirmationNumber, item.confirmationNumber) && dayOk(e)).firstOrNull ??
          travel.where((e) =>
              e.type == item.type && _sameDay(e.date, item.date) &&
              ((e.time != null && e.time == item.time) || _sameText(e.title, item.title))).firstOrNull;
    case ParsedStay(:final stay):
      return stays.where((e) => _sameRef(e.confirmationNumber, stay.confirmationNumber)).firstOrNull ??
          stays.where((e) => _sameText(e.name, stay.name) &&
              (stay.checkIn == null || _sameDay(e.checkIn, stay.checkIn))).firstOrNull;
    case ParsedPlan(:final item, :final day):
      final d = days.where((d) => _sameDay(d.date, day)).firstOrNull;
      return d?.items.where((e) => _sameText(e.title, item.title)).firstOrNull;
  }
}

/// [existing] with every empty field filled from [parsed]. Nothing the group
/// already entered is overwritten.
TravelItem mergeTravel(TravelItem existing, TravelItem parsed) => TravelItem(
      id: existing.id,
      title: existing.title,
      type: existing.type,
      status: existing.status,
      date: existing.date ?? parsed.date,
      endDate: existing.endDate ?? parsed.endDate,
      time: existing.time ?? parsed.time,
      endTime: existing.endTime ?? parsed.endTime,
      location: existing.location ?? parsed.location,
      destination: existing.destination ?? parsed.destination,
      confirmationNumber: existing.confirmationNumber ?? parsed.confirmationNumber,
      url: existing.url ?? parsed.url,
      address: existing.address ?? parsed.address,
      notes: mergeNotes(existing.notes, parsed.notes),
      departureTerminal: existing.departureTerminal ?? parsed.departureTerminal,
      arrivalTerminal: existing.arrivalTerminal ?? parsed.arrivalTerminal,
      gate: existing.gate ?? parsed.gate,
      seat: existing.seat ?? parsed.seat,
      boardingTime: existing.boardingTime ?? parsed.boardingTime,
      travellers: existing.travellers.isEmpty ? parsed.travellers : existing.travellers,
      linkedDocIds: existing.linkedDocIds,
      linkedItineraryItemId: existing.linkedItineraryItemId,
      linkedDayId: existing.linkedDayId,
    );

/// [existing] with every empty field filled from [parsed]; a confirmation
/// marks a brainstormed stay as booked.
Accommodation mergeStay(Accommodation existing, Accommodation parsed) => existing.copyWith(
      city: existing.city.isEmpty ? parsed.city : null,
      address: existing.address ?? parsed.address,
      url: existing.url ?? parsed.url,
      pricePerNight: existing.pricePerNight ?? parsed.pricePerNight,
      currency: existing.pricePerNight == null ? parsed.currency : null,
      checkIn: existing.checkIn ?? parsed.checkIn,
      checkOut: existing.checkOut ?? parsed.checkOut,
      checkInTime: existing.checkInTime ?? parsed.checkInTime,
      checkOutTime: existing.checkOutTime ?? parsed.checkOutTime,
      confirmationNumber: existing.confirmationNumber ?? parsed.confirmationNumber,
      notes: mergeNotes(existing.notes, parsed.notes),
      status: parsed.status == AccommodationStatus.booked ? AccommodationStatus.booked : null,
    );

/// [existing] notes plus any line of [parsed] they don't already contain
/// (e.g. the host's phone number from the booking), so updating a booking
/// adds what's new without rewriting what the group wrote.
String? mergeNotes(String? existing, String? parsed) {
  if (existing == null || existing.trim().isEmpty) return parsed;
  if (parsed == null) return existing;
  final have = foldForSearch(existing);
  final added = parsed
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !have.contains(foldForSearch(l)))
      .toList();
  return added.isEmpty ? existing : '${existing.trimRight()}\n${added.join('\n')}';
}
