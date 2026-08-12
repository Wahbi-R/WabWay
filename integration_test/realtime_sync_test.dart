// ignore_for_file: avoid_print
//
// Two-client realtime sync tests — every feature table.
// Client A simulates mobile, Client B simulates browser.
// Each test: A writes → B receives the Postgres change event within 6 s,
// and B writes → A receives. Test data is cleaned up after each test.
//
// Prerequisites:
//   Two WabWay accounts that are BOTH members of the same trip.
//   Add to your .env file:
//     TEST_EMAIL=user-a@example.com     TEST_PASSWORD=passwordA
//     TEST_EMAIL_2=user-b@example.com   TEST_PASSWORD_2=passwordB
//
// Run:
//   flutter test integration_test/realtime_sync_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'helpers.dart';

// ── Two-client setup ──────────────────────────────────────────────────────────

/// A raw SupabaseClient (NOT the Flutter singleton) — its own auth session.
SupabaseClient _makeClient() => SupabaseClient(kSupabaseUrl, kSupabaseKey);

Future<String> _signInClient(SupabaseClient c, String email, String pw) async {
  final res = await c.auth.signInWithPassword(email: email, password: pw);
  assert(res.user != null, 'Sign-in failed for $email');
  return res.user!.id;
}

/// Finds the first trip shared by both users. Marks the test skipped if none.
Future<String?> _sharedTrip(SupabaseClient c, String uidA, String uidB) async {
  final rowsA = await c.from('trip_members').select('trip_id').eq('user_id', uidA);
  final setA  = {for (final r in rowsA) r['trip_id'] as String};
  final rowsB = await c.from('trip_members').select('trip_id').eq('user_id', uidB);
  for (final r in rowsB) {
    final id = r['trip_id'] as String;
    if (setA.contains(id)) return id;
  }
  return null;
}

// ── Core sync helper ──────────────────────────────────────────────────────────

const _kTimeout = Duration(seconds: 8);

/// Subscribes [listener] to [event] on [table] (filtered to [tripId]) using
/// [subscriber] client, waits for [writer] to call [write], then asserts
/// [check] on the received payload. Cleans up with [cleanup] afterwards.
Future<void> _syncTest({
  required String label,
  required SupabaseClient writer,
  required SupabaseClient subscriber,
  required String table,
  required String tripId,
  required PostgresChangeEvent event,
  required Future<Map<String, dynamic>> Function() write,
  required void Function(Map<String, dynamic> payload) check,
  required Future<void> Function(Map<String, dynamic> written) cleanup,
}) async {
  final received = Completer<Map<String, dynamic>>();
  Map<String, dynamic>? written;

  final channel = subscriber
      .channel('$table:$tripId:${event.name}:$label')
      .onPostgresChanges(
        event: event,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (p) {
          final row = event == PostgresChangeEvent.delete
              ? p.oldRecord
              : p.newRecord;
          if (!received.isCompleted) received.complete(row);
        },
      )
      .subscribe();

  // Give the subscription time to establish over the websocket.
  await Future<void>.delayed(const Duration(seconds: 2));

  try {
    written = await write();
    print('[realtime] [$label] written: $written');

    final payload = await received.future.timeout(
      _kTimeout,
      onTimeout: () => throw TimeoutException(
        '[$label] second client did not receive $event on $table within $_kTimeout',
      ),
    );
    print('[realtime] [$label] received: $payload');
    check(payload);
  } finally {
    if (written != null) await cleanup(written);
    await subscriber.removeChannel(channel);
  }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initSupabase);

  // Each group gets its own pair of clients + a shared tripId.
  late SupabaseClient A; // "mobile"
  late SupabaseClient B; // "browser"
  late String uidA;
  late String uidB;
  late String tripId;

  setUp(() async {
    assert(kTestEmail.isNotEmpty && kTestEmail2.isNotEmpty,
        'TEST_EMAIL / TEST_EMAIL_2 missing in .env');
    A = _makeClient();
    B = _makeClient();
    uidA = await _signInClient(A, kTestEmail, kTestPassword);
    uidB = await _signInClient(B, kTestEmail2, kTestPassword2);
    final shared = await _sharedTrip(A, uidA, uidB);
    if (shared == null) {
      await A.dispose();
      await B.dispose();
      markTestSkipped(
        'No shared trip between $kTestEmail and $kTestEmail2. '
        'Add both accounts to the same trip first.',
      );
      return;
    }
    tripId = shared;
    print('[realtime] using trip $tripId');
  });

  tearDown(() async {
    await A.dispose();
    await B.dispose();
  });

  // ── 1. Packing items ────────────────────────────────────────────────────────

  group('Packing items', () {
    test('A adds item → B receives INSERT', () async {
      final title = 'RT packing ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'packing-insert',
        writer: A, subscriber: B,
        table: 'packing_items', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async {
          final r = await A.from('packing_items').insert({
            'trip_id': tripId, 'title': title, 'created_by': uidA, 'is_packed': false,
          }).select().single();
          return r;
        },
        check: (p) {
          expect(p['title'], equals(title));
          expect(p['trip_id'], equals(tripId));
        },
        cleanup: (w) async => A.from('packing_items').delete().eq('id', w['id']),
      );
    });

    test('B toggles item packed → A receives UPDATE', () async {
      final r = await A.from('packing_items').insert({
        'trip_id': tripId, 'title': 'RT toggle ${DateTime.now().millisecondsSinceEpoch}',
        'created_by': uidA, 'is_packed': false,
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'packing-update',
        writer: B, subscriber: A,
        table: 'packing_items', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('packing_items').update({'is_packed': true, 'packed_by': uidB}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['is_packed'], isTrue),
        cleanup: (_) async => A.from('packing_items').delete().eq('id', id),
      );
    });
  });

  // ── 2. Shopping items ───────────────────────────────────────────────────────

  group('Shopping items', () {
    test('A adds item → B receives INSERT', () async {
      final name = 'RT shopping ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'shopping-insert',
        writer: A, subscriber: B,
        table: 'shopping_items', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('shopping_items').insert({
          'trip_id': tripId, 'name': name, 'added_by': uidA,
        }).select().single(),
        check: (p) => expect(p['name'], equals(name)),
        cleanup: (w) async => A.from('shopping_items').delete().eq('id', w['id']),
      );
    });

    test('B checks off item → A receives UPDATE', () async {
      final r = await A.from('shopping_items').insert({
        'trip_id': tripId, 'name': 'RT check ${DateTime.now().millisecondsSinceEpoch}',
        'added_by': uidA, 'is_checked': false,
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'shopping-update',
        writer: B, subscriber: A,
        table: 'shopping_items', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('shopping_items').update({'is_checked': true}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['is_checked'], isTrue),
        cleanup: (_) async => A.from('shopping_items').delete().eq('id', id),
      );
    });
  });

  // ── 3. Spots ────────────────────────────────────────────────────────────────

  group('Spots', () {
    test('A adds spot → B receives INSERT', () async {
      final name = 'RT spot ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'spots-insert',
        writer: A, subscriber: B,
        table: 'spots', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('spots').insert({
          'trip_id': tripId, 'name': name, 'city': 'Test City',
          'added_by': uidA, 'status': 'saved',
        }).select().single(),
        check: (p) => expect(p['name'], equals(name)),
        cleanup: (w) async => A.from('spots').delete().eq('id', w['id']),
      );
    });

    test('B marks spot visited → A receives UPDATE', () async {
      final r = await A.from('spots').insert({
        'trip_id': tripId, 'name': 'RT spot update ${DateTime.now().millisecondsSinceEpoch}',
        'city': 'Test City', 'added_by': uidA, 'status': 'saved',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'spots-update',
        writer: B, subscriber: A,
        table: 'spots', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('spots').update({'status': 'visited'}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['status'], equals('visited')),
        cleanup: (_) async => A.from('spots').delete().eq('id', id),
      );
    });

    test('B deletes spot → A receives DELETE', () async {
      final r = await A.from('spots').insert({
        'trip_id': tripId, 'name': 'RT spot delete ${DateTime.now().millisecondsSinceEpoch}',
        'city': 'Test City', 'added_by': uidA, 'status': 'saved',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'spots-delete',
        writer: B, subscriber: A,
        table: 'spots', tripId: tripId,
        event: PostgresChangeEvent.delete,
        write: () async {
          await B.from('spots').delete().eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['id'] ?? id, isNotEmpty),
        cleanup: (_) async {},
      );
    });
  });

  // ── 4. Plan — itinerary items ───────────────────────────────────────────────

  group('Plan items (itinerary_items)', () {
    late String dayId;

    setUp(() async {
      // Need an itinerary day to attach items to.
      final existing = await A.from('itinerary_days').select().eq('trip_id', tripId).limit(1);
      if (existing.isNotEmpty) {
        dayId = existing.first['id'] as String;
      } else {
        final d = await A.from('itinerary_days').insert({
          'trip_id': tripId, 'day_number': 99, 'date': '2099-01-01',
        }).select().single();
        dayId = d['id'] as String;
      }
    });

    test('A adds plan item → B receives INSERT', () async {
      final title = 'RT plan ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'plan-insert',
        writer: A, subscriber: B,
        table: 'itinerary_items', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('itinerary_items').insert({
          'trip_id': tripId, 'day_id': dayId, 'title': title,
          'item_type': 'activity',
        }).select().single(),
        check: (p) => expect(p['title'], equals(title)),
        cleanup: (w) async => A.from('itinerary_items').delete().eq('id', w['id']),
      );
    });

    test('B marks item done → A receives UPDATE', () async {
      final r = await A.from('itinerary_items').insert({
        'trip_id': tripId, 'day_id': dayId,
        'title': 'RT plan done ${DateTime.now().millisecondsSinceEpoch}',
        'item_type': 'activity', 'is_done': false,
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'plan-update',
        writer: B, subscriber: A,
        table: 'itinerary_items', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('itinerary_items').update({'is_done': true}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['is_done'], isTrue),
        cleanup: (_) async => A.from('itinerary_items').delete().eq('id', id),
      );
    });
  });

  // ── 5. Receipts (Money) ─────────────────────────────────────────────────────

  group('Receipts (Money)', () {
    test('A adds receipt → B receives INSERT', () async {
      final title = 'RT receipt ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'receipts-insert',
        writer: A, subscriber: B,
        table: 'receipts', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('receipts').insert({
          'trip_id': tripId, 'title': title, 'amount': 9.99,
          'currency': 'USD', 'paid_by': uidA, 'category': 'food',
        }).select().single(),
        check: (p) => expect(p['title'], equals(title)),
        cleanup: (w) async => A.from('receipts').delete().eq('id', w['id']),
      );
    });

    test('B deletes receipt → A receives DELETE', () async {
      final r = await A.from('receipts').insert({
        'trip_id': tripId, 'title': 'RT receipt del ${DateTime.now().millisecondsSinceEpoch}',
        'amount': 1.00, 'currency': 'USD', 'paid_by': uidA, 'category': 'other',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'receipts-delete',
        writer: B, subscriber: A,
        table: 'receipts', tripId: tripId,
        event: PostgresChangeEvent.delete,
        write: () async {
          await B.from('receipts').delete().eq('id', id);
          return {'id': id};
        },
        check: (_) {},
        cleanup: (_) async {},
      );
    });
  });

  // ── 6. Documents ────────────────────────────────────────────────────────────

  group('Documents', () {
    test('A adds document → B receives INSERT', () async {
      final title = 'RT doc ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'documents-insert',
        writer: A, subscriber: B,
        table: 'documents', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('documents').insert({
          'trip_id': tripId, 'title': title,
          'uploaded_by': uidA, 'doc_type': 'other',
        }).select().single(),
        check: (p) => expect(p['title'], equals(title)),
        cleanup: (w) async => A.from('documents').delete().eq('id', w['id']),
      );
    });

    test('B edits document title → A receives UPDATE', () async {
      final r = await A.from('documents').insert({
        'trip_id': tripId, 'title': 'RT doc update ${DateTime.now().millisecondsSinceEpoch}',
        'uploaded_by': uidA, 'doc_type': 'other',
      }).select().single();
      final id = r['id'] as String;
      final updatedTitle = 'RT doc updated ${DateTime.now().millisecondsSinceEpoch}';

      await _syncTest(
        label: 'documents-update',
        writer: B, subscriber: A,
        table: 'documents', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('documents').update({'title': updatedTitle}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['title'], equals(updatedTitle)),
        cleanup: (_) async => A.from('documents').delete().eq('id', id),
      );
    });
  });

  // ── 7. Travel items ─────────────────────────────────────────────────────────

  group('Travel items', () {
    test('A adds travel item → B receives INSERT', () async {
      final title = 'RT travel ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'travel-insert',
        writer: A, subscriber: B,
        table: 'travel_items', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('travel_items').insert({
          'trip_id': tripId, 'title': title,
          'added_by': uidA, 'type': 'flight',
        }).select().single(),
        check: (p) => expect(p['title'], equals(title)),
        cleanup: (w) async => A.from('travel_items').delete().eq('id', w['id']),
      );
    });

    test('B edits travel item → A receives UPDATE', () async {
      final r = await A.from('travel_items').insert({
        'trip_id': tripId, 'title': 'RT travel upd ${DateTime.now().millisecondsSinceEpoch}',
        'added_by': uidA, 'type': 'flight',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'travel-update',
        writer: B, subscriber: A,
        table: 'travel_items', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('travel_items').update({'status': 'confirmed'}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['status'], equals('confirmed')),
        cleanup: (_) async => A.from('travel_items').delete().eq('id', id),
      );
    });
  });

  // ── 8. Accommodations (Stays) ───────────────────────────────────────────────

  group('Accommodations (Stays)', () {
    test('A adds stay → B receives INSERT', () async {
      final name = 'RT stay ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'stays-insert',
        writer: A, subscriber: B,
        table: 'accommodations', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('accommodations').insert({
          'trip_id': tripId, 'name': name, 'added_by': uidA, 'status': 'upcoming',
        }).select().single(),
        check: (p) => expect(p['name'], equals(name)),
        cleanup: (w) async => A.from('accommodations').delete().eq('id', w['id']),
      );
    });

    test('B updates stay status → A receives UPDATE', () async {
      final r = await A.from('accommodations').insert({
        'trip_id': tripId, 'name': 'RT stay upd ${DateTime.now().millisecondsSinceEpoch}',
        'added_by': uidA, 'status': 'upcoming',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'stays-update',
        writer: B, subscriber: A,
        table: 'accommodations', tripId: tripId,
        event: PostgresChangeEvent.update,
        write: () async {
          await B.from('accommodations').update({'status': 'checked_in'}).eq('id', id);
          return {'id': id};
        },
        check: (p) => expect(p['status'], equals('checked_in')),
        cleanup: (_) async => A.from('accommodations').delete().eq('id', id),
      );
    });
  });

  // ── 9. Links ────────────────────────────────────────────────────────────────

  group('Links', () {
    test('A adds link → B receives INSERT', () async {
      final title = 'RT link ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'links-insert',
        writer: A, subscriber: B,
        table: 'trip_links', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('trip_links').insert({
          'trip_id': tripId, 'title': title,
          'url': 'https://example.com', 'added_by': uidA, 'category': 'other',
        }).select().single(),
        check: (p) => expect(p['title'], equals(title)),
        cleanup: (w) async => A.from('trip_links').delete().eq('id', w['id']),
      );
    });

    test('B deletes link → A receives DELETE', () async {
      final r = await A.from('trip_links').insert({
        'trip_id': tripId, 'title': 'RT link del ${DateTime.now().millisecondsSinceEpoch}',
        'url': 'https://example.com', 'added_by': uidA, 'category': 'other',
      }).select().single();
      final id = r['id'] as String;

      await _syncTest(
        label: 'links-delete',
        writer: B, subscriber: A,
        table: 'trip_links', tripId: tripId,
        event: PostgresChangeEvent.delete,
        write: () async {
          await B.from('trip_links').delete().eq('id', id);
          return {'id': id};
        },
        check: (_) {},
        cleanup: (_) async {},
      );
    });
  });

  // ── 10. Crew chat (trip_messages) ───────────────────────────────────────────

  group('Crew chat', () {
    test('A sends message → B receives INSERT', () async {
      final content = 'RT chat ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'chat-insert',
        writer: A, subscriber: B,
        table: 'trip_messages', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => A.from('trip_messages').insert({
          'trip_id': tripId, 'sender_id': uidA,
          'message_type': 'text', 'content': content,
        }).select().single(),
        check: (p) => expect(p['content'], equals(content)),
        cleanup: (w) async => A.from('trip_messages').delete().eq('id', w['id']),
      );
    });

    test('B sends message → A receives INSERT', () async {
      final content = 'RT chat B→A ${DateTime.now().millisecondsSinceEpoch}';
      await _syncTest(
        label: 'chat-insert-reverse',
        writer: B, subscriber: A,
        table: 'trip_messages', tripId: tripId,
        event: PostgresChangeEvent.insert,
        write: () async => B.from('trip_messages').insert({
          'trip_id': tripId, 'sender_id': uidB,
          'message_type': 'text', 'content': content,
        }).select().single(),
        check: (p) => expect(p['content'], equals(content)),
        cleanup: (w) async => A.from('trip_messages').delete().eq('id', w['id']),
      );
    });
  });

  // ── 11. Trip members ────────────────────────────────────────────────────────
  // Note: we only test that existing membership changes propagate —
  // we don't add/remove real members as that would require invite codes.

  group('Trip members', () {
    test('both users can see each other in trip_members', () async {
      final rows = await A
          .from('trip_members')
          .select('user_id')
          .eq('trip_id', tripId);
      final userIds = rows.map((r) => r['user_id'] as String).toSet();
      expect(userIds.contains(uidA), isTrue,
          reason: 'User A should be a member of the shared trip');
      expect(userIds.contains(uidB), isTrue,
          reason: 'User B should be a member of the shared trip');
    });
  });
}
