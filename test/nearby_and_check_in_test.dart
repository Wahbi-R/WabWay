import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/nearby_service.dart';
import 'package:wabway/data/crew_data.dart';
import 'package:wabway/data/spot_data.dart';
import 'package:wabway/screens/crew/whereabouts.dart';

// Nearby: parsing what /places/nearby returns. Crew: check-ins that work
// without GPS ("Uniqlo · 3F · near the escalators").
void main() {
  group('NearbyPlace', () {
    final json = <String, dynamic>{
      'name': 'Ichiran Shibuya',
      'place_id': 'abc',
      'address': '1-22-7 Jinnan',
      'city': 'Tokyo',
      'area': 'Shibuya',
      'country': 'Japan',
      'category': 'food',
      'type_label': 'Ramen restaurant',
      'latitude': 35.661,
      'longitude': 139.7,
      'distance_m': 364,
      'rating': 4.4,
      'rating_count': 12034,
      'price_level': 1,
      'price_range': '¥1,000–¥2,000',
      'open_now': true,
      'closes_soon': false,
      'weekday_hours': [
        'Monday: 10:00 AM – 11:00 PM',
        'Tuesday: 10:00 AM – 11:00 PM',
        'Wednesday: Closed',
        'Thursday: 10:00 AM – 11:00 PM',
        'Friday: 10:00 AM – 2:00 AM',
        'Saturday: Open 24 hours',
        'Sunday: 10:00 AM – 11:00 PM',
      ],
      'maps_url': 'https://maps.google.com/?cid=1',
      'photo_name': 'places/abc/photos/xyz',
    };

    test('parses the server result', () {
      final p = NearbyPlace.fromJson(json);
      expect(p.name, 'Ichiran Shibuya');
      expect(p.category, SpotCategory.food);
      expect(p.rating, 4.4);
      expect(p.ratingCount, 12034);
      expect(p.distanceM, 364);
      expect(p.openNow, isTrue);
      expect(p.priceLabel, '¥1,000–¥2,000');
      expect(p.mapsLink, 'https://maps.google.com/?cid=1');
    });

    test("today's hours come from the phone's weekday", () {
      final p = NearbyPlace.fromJson(json);
      expect(p.hoursOn(DateTime(2026, 11, 11)), 'Closed'); // a Wednesday
      expect(p.hoursOn(DateTime(2026, 11, 14)), 'Open 24 hours'); // Saturday
      expect(NearbyPlace.fromJson({'name': 'x'}).hoursOn(DateTime(2026, 11, 14)), isNull);
    });

    test('price falls back to \$ signs, Maps link to coordinates', () {
      final p = NearbyPlace.fromJson({'name': 'Cafe', 'price_level': 2, 'latitude': 1.5, 'longitude': 2.5});
      expect(p.priceLabel, r'$$');
      expect(p.mapsLink, contains('query=1.5,2.5'));
      expect(NearbyPlace.fromJson({'name': 'Park', 'price_level': 0}).priceLabel, 'Free');
    });

    test('becomes a place suggestion for Add spot', () {
      final s = NearbyPlace.fromJson(json).toSuggestion();
      expect(s.name, 'Ichiran Shibuya');
      expect(s.city, 'Tokyo');
      expect(s.area, 'Shibuya');
      expect(s.category, SpotCategory.food);
      expect(s.placeId, 'abc');
    });

    test('formatting', () {
      expect(fmtDistance(364), '360 m');
      expect(fmtDistance(1240), '1.2 km');
      expect(fmtDistance(15400), '15 km');
      expect(fmtCount(950), '950');
      expect(fmtCount(1000), '1k');
      expect(fmtCount(1260), '1.3k');
      expect(fmtCount(12034), '12k');
      expect(fmtWalk(364), '5 min walk');
      expect(fmtWalk(10), '1 min walk');
    });
  });

  group('check-ins', () {
    TripMessage msg(String author, MessageType type, DateTime at, [String body = '']) =>
        TripMessage(id: '$author$at', tripId: 't', authorId: author, body: body, type: type, createdAt: at);

    test('latest fresh check-in per person, newest first', () {
      final now = DateTime(2026, 11, 13, 15);
      final list = latestCheckIns([
        msg('sam', MessageType.checkIn, now.subtract(const Duration(hours: 5)), 'Hotel'),
        msg('sam', MessageType.checkIn, now.subtract(const Duration(minutes: 40)), 'Uniqlo · 3F'),
        msg('sam', MessageType.checkIn, now.subtract(const Duration(minutes: 50)), 'GU'),
        msg('ana', MessageType.checkIn, now.subtract(const Duration(minutes: 10)), 'Food court'),
        msg('lee', MessageType.checkIn, now.subtract(const Duration(hours: 4)), 'Too old'),
        msg('lee', MessageType.text, now, 'hi'),
      ], now);
      expect(list.map((m) => m.body), ['Food court', 'Uniqlo · 3F']);
    });

    test('composes the check-in line', () {
      expect(composeCheckIn(place: ' Uniqlo ', floor: '3F', near: 'the escalators'),
          'Uniqlo · 3F · near the escalators');
      expect(composeCheckIn(place: 'Food court', near: 'next to Starbucks'), 'Food court · next to Starbucks');
      expect(composeCheckIn(place: 'Gate 3'), 'Gate 3');
    });

    test('older app versions read new message types', () {
      final m = TripMessage.fromMap({
        'id': '1', 'trip_id': 't', 'author_id': 'a', 'body': 'Where is everyone?',
        'message_type': 'where_ask', 'created_at': '2026-11-13T10:00:00Z',
      });
      expect(m.type, MessageType.whereAsk);
    });

    testWidgets('the strip offers to check in and shows the crew', (tester) async {
      var tapped = false;
      final now = DateTime.now();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WhereaboutsStrip(
            checkIns: [msg('ana', MessageType.checkIn, now, 'Food court · B1')],
            members: const [],
            currentUserId: 'me',
            onCheckIn: () => tapped = true,
            onOpen: (_) {},
          ),
        ),
      ));
      expect(find.text('Food court · B1'), findsOneWidget);
      await tester.tap(find.text("I'm at…"));
      expect(tapped, isTrue);
    });
  });
}
