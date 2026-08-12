// ignore_for_file: avoid_print
//
// Two-client realtime sync tests — verifies that a write on one client
// (simulating mobile) is received by a second client (simulating browser)
// via Supabase Realtime, and vice versa.
//
// Prerequisites:
//   Two WabWay accounts that are BOTH members of the same trip.
//   Add to your .env file:
//     TEST_EMAIL=user-a@example.com
//     TEST_PASSWORD=passwordA
//     TEST_EMAIL_2=user-b@example.com
//     TEST_PASSWORD_2=passwordB
//
// Run on a connected device or emulator:
//   flutter test integration_test/realtime_sync_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl  = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey  = String.fromEnvironment('SUPABASE_ANON_KEY');
const _emailA       = String.fromEnvironment('TEST_EMAIL');
const _passwordA    = String.fromEnvironment('TEST_PASSWORD');
const _emailB       = String.fromEnvironment('TEST_EMAIL_2');
const _passwordB    = String.fromEnvironment('TEST_PASSWORD_2');

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Creates a raw SupabaseClient (not the Flutter singleton) with its own
/// auth session. Used to simulate a second, independent device.
SupabaseClient _makeClient() => SupabaseClient(_supabaseUrl, _supabaseKey);

/// Signs [client] in and returns the user id.
Future<String> _signIn(
  SupabaseClient client,
  String email,
  String password,
) async {
  final res = await client.auth.signInWithPassword(email: email, password: password);
  assert(res.user != null, 'Sign-in failed for $email');
  return res.user!.id;
}

/// Finds the first trip that both [userIdA] and [userIdB] share.
/// Returns null if no shared trip exists.
Future<String?> _sharedTripId(
  SupabaseClient client,
  String userIdA,
  String userIdB,
) async {
  final rowsA = await client
      .from('trip_members')
      .select('trip_id')
      .eq('user_id', userIdA);
  final tripsA = {for (final r in rowsA) r['trip_id'] as String};

  final rowsB = await client
      .from('trip_members')
      .select('trip_id')
      .eq('user_id', userIdB);

  for (final r in rowsB) {
    final id = r['trip_id'] as String;
    if (tripsA.contains(id)) return id;
  }
  return null;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    assert(_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty,
        'SUPABASE_URL / SUPABASE_ANON_KEY missing. Run with --dart-define-from-file=.env');
    assert(_emailA.isNotEmpty && _passwordA.isNotEmpty,
        'TEST_EMAIL / TEST_PASSWORD missing in .env');
    assert(_emailB.isNotEmpty && _passwordB.isNotEmpty,
        'TEST_EMAIL_2 / TEST_PASSWORD_2 missing in .env');

    // Initialize the Flutter singleton (needed for platform channels, etc.)
    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
  });

  // ── Packing list ──────────────────────────────────────────────────────────

  group('Packing list realtime sync', () {
    late SupabaseClient clientA; // "mobile" user
    late SupabaseClient clientB; // "browser" user
    late String userIdA;
    late String userIdB;
    late String tripId;

    setUp(() async {
      clientA = _makeClient();
      clientB = _makeClient();
      userIdA = await _signIn(clientA, _emailA, _passwordA);
      userIdB = await _signIn(clientB, _emailB, _passwordB);

      final shared = await _sharedTripId(clientA, userIdA, userIdB);
      if (shared == null) {
        markTestSkipped(
          'No shared trip found between $_emailA and $_emailB. '
          'Ensure both accounts are members of the same trip.',
        );
        return;
      }
      tripId = shared;
      print('[realtime] Using trip $tripId');
    });

    tearDown(() async {
      await clientA.dispose();
      await clientB.dispose();
    });

    test('mobile adds a packing item → browser receives it via realtime', () async {
      final itemTitle = 'Sync test item ${DateTime.now().millisecondsSinceEpoch}';
      final received = Completer<Map<String, dynamic>>();

      // Client B subscribes to INSERT events on packing_items for this trip
      final channel = clientB
          .channel('packing_items:$tripId:insert')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'packing_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: tripId,
            ),
            callback: (payload) {
              if (!received.isCompleted) {
                received.complete(payload.newRecord);
              }
            },
          )
          .subscribe();

      // Give the subscription time to establish
      await Future<void>.delayed(const Duration(seconds: 2));

      // Client A inserts a packing item
      print('[realtime] Client A (mobile) inserting "$itemTitle"');
      await clientA.from('packing_items').insert({
        'trip_id':    tripId,
        'title':      itemTitle,
        'created_by': userIdA,
        'is_packed':  false,
      });

      // Client B should receive the realtime event within 6 seconds
      final row = await received.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException(
          'Browser client did not receive INSERT event within 6 s',
        ),
      );

      print('[realtime] ✓ Browser received: ${row['title']}');
      expect(row['title'], equals(itemTitle));
      expect(row['trip_id'], equals(tripId));

      // Clean up: delete the test item
      await clientA
          .from('packing_items')
          .delete()
          .eq('title', itemTitle)
          .eq('trip_id', tripId);

      await clientB.removeChannel(channel);
    });

    test('browser toggles a packing item → mobile receives UPDATE via realtime', () async {
      // First, create a packing item as client A
      final itemTitle = 'Toggle sync test ${DateTime.now().millisecondsSinceEpoch}';
      final insertRow = await clientA
          .from('packing_items')
          .insert({
            'trip_id':    tripId,
            'title':      itemTitle,
            'created_by': userIdA,
            'is_packed':  false,
          })
          .select()
          .single();
      final itemId = insertRow['id'] as String;

      final received = Completer<Map<String, dynamic>>();

      // Client A subscribes to UPDATE events (simulating mobile watching the list)
      final channel = clientA
          .channel('packing_items:$tripId:update')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'packing_items',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: tripId,
            ),
            callback: (payload) {
              if (!received.isCompleted && payload.newRecord['id'] == itemId) {
                received.complete(payload.newRecord);
              }
            },
          )
          .subscribe();

      await Future<void>.delayed(const Duration(seconds: 2));

      // Client B (browser) toggles the item as packed
      print('[realtime] Client B (browser) toggling "$itemTitle" as packed');
      await clientB.from('packing_items').update({
        'is_packed': true,
        'packed_by': userIdB,
      }).eq('id', itemId);

      // Client A should receive the UPDATE
      final row = await received.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException(
          'Mobile client did not receive UPDATE event within 6 s',
        ),
      );

      print('[realtime] ✓ Mobile received update: is_packed=${row['is_packed']}');
      expect(row['is_packed'], isTrue);
      expect(row['packed_by'], equals(userIdB));

      // Clean up
      await clientA.from('packing_items').delete().eq('id', itemId);
      await clientA.removeChannel(channel);
    });
  });

  // ── Crew chat ─────────────────────────────────────────────────────────────

  group('Crew chat realtime sync', () {
    late SupabaseClient clientA;
    late SupabaseClient clientB;
    late String userIdA;
    late String tripId;

    setUp(() async {
      clientA = _makeClient();
      clientB = _makeClient();
      userIdA = await _signIn(clientA, _emailA, _passwordA);
      final userIdB = await _signIn(clientB, _emailB, _passwordB);

      final shared = await _sharedTripId(clientA, userIdA, userIdB);
      if (shared == null) {
        markTestSkipped(
          'No shared trip found — ensure both accounts are members of the same trip.',
        );
        return;
      }
      tripId = shared;
    });

    tearDown(() async {
      await clientA.dispose();
      await clientB.dispose();
    });

    test('mobile sends a message → browser receives it via realtime', () async {
      final messageText = 'Hello from mobile ${DateTime.now().millisecondsSinceEpoch}';
      final received = Completer<Map<String, dynamic>>();

      // Client B subscribes to new messages
      final channel = clientB
          .channel('trip_messages:$tripId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'trip_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'trip_id',
              value: tripId,
            ),
            callback: (payload) {
              if (!received.isCompleted) {
                received.complete(payload.newRecord);
              }
            },
          )
          .subscribe();

      await Future<void>.delayed(const Duration(seconds: 2));

      // Client A sends a message
      print('[realtime] Client A sending: "$messageText"');
      await clientA.from('trip_messages').insert({
        'trip_id':      tripId,
        'sender_id':    userIdA,
        'message_type': 'text',
        'content':      messageText,
      });

      final row = await received.future.timeout(
        const Duration(seconds: 6),
        onTimeout: () => throw TimeoutException(
          'Browser client did not receive chat message within 6 s',
        ),
      );

      print('[realtime] ✓ Browser received: ${row['content']}');
      expect(row['content'], equals(messageText));
      expect(row['trip_id'], equals(tripId));

      // Clean up
      await clientA
          .from('trip_messages')
          .delete()
          .eq('content', messageText)
          .eq('trip_id', tripId);

      await clientB.removeChannel(channel);
    });
  });
}
