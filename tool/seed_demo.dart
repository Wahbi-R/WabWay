// ignore_for_file: avoid_print
/// Seed script — populates the test account with a realistic Japan trip.
///
/// Usage:
///   dart run tool/seed_demo.dart
///
/// Reads SUPABASE_URL, SUPABASE_ANON_KEY, TEST_EMAIL, TEST_PASSWORD from .env
/// (same file used by flutter run).  All existing trips owned by the test user
/// are deleted first, then a fresh trip is created with spots, plan days,
/// travel bookings, receipts, packing items, shopping items, and crew chat.
library;

import 'dart:io';
import 'package:supabase/supabase.dart';

// ─── .env reader ─────────────────────────────────────────────────────────────

Map<String, String> _readEnv() {
  final file = File('.env');
  if (!file.existsSync()) throw Exception('.env not found — run from project root');
  final env = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx < 0) continue;
    env[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
  return env;
}

// ─── Main ─────────────────────────────────────────────────────────────────────

Future<void> main() async {
  final env = _readEnv();
  final url  = env['SUPABASE_URL']  ?? '';
  final key  = env['SUPABASE_ANON_KEY'] ?? '';
  final email    = env['TEST_EMAIL']    ?? '';
  final password = env['TEST_PASSWORD'] ?? '';

  if (url.isEmpty || key.isEmpty) throw Exception('SUPABASE_URL / SUPABASE_ANON_KEY missing in .env');
  if (email.isEmpty || password.isEmpty) throw Exception('TEST_EMAIL / TEST_PASSWORD missing in .env');

  final sb = SupabaseClient(url, key);

  // ── Sign in ────────────────────────────────────────────────────────────────
  print('Signing in as $email …');
  final auth = await sb.auth.signInWithPassword(email: email, password: password);
  final userId = auth.user!.id;
  print('Signed in: $userId');

  // ── Wipe existing trips ────────────────────────────────────────────────────
  print('Deleting existing trips …');
  // RLS returns only trips the signed-in user is a member of
  final existingTrips = await sb.from('trips').select('id');
  for (final t in existingTrips as List) {
    await sb.from('trips').delete().eq('id', t['id'] as String);
  }
  print('Deleted ${existingTrips.length} trip(s)');

  // ── Create trip ────────────────────────────────────────────────────────────
  print('Creating demo trip …');
  final today = DateTime.now();
  // Trip starts in 5 days so it's pre-trip (to show "First up" on Home)
  final startDate = today.add(const Duration(days: 5));
  final endDate   = startDate.add(const Duration(days: 13));

  final tripId = await sb.rpc('create_trip_with_owner', params: {
    'p_name':             'Japan 2026',
    'p_destination':      'Japan',
    'p_start_date':       _isoDate(startDate),
    'p_end_date':         _isoDate(endDate),
    'p_default_currency': 'JPY',
  }) as String;
  print('Trip created: $tripId');

  // ── Spots ──────────────────────────────────────────────────────────────────
  print('Seeding spots …');
  final spots = [
    {'name': 'Senso-ji Temple', 'city': 'Tokyo', 'area': 'Asakusa', 'category': 'landmark', 'status': 'must_do', 'notes': 'Go early morning to avoid crowds. The Nakamise shopping street is great for souvenirs.'},
    {'name': 'Tsukiji Outer Market', 'city': 'Tokyo', 'area': 'Tsukiji', 'category': 'food', 'status': 'confirmed', 'notes': 'Breakfast spot — try the tuna sashimi and tamagoyaki on a stick.'},
    {'name': 'Shibuya Crossing', 'city': 'Tokyo', 'area': 'Shibuya', 'category': 'landmark', 'status': 'want_to_go'},
    {'name': 'teamLab Borderless', 'city': 'Tokyo', 'area': 'Odaiba', 'category': 'experience', 'status': 'booked', 'notes': 'Tickets already purchased for Day 3!'},
    {'name': 'Arashiyama Bamboo Grove', 'city': 'Kyoto', 'area': 'Arashiyama', 'category': 'nature', 'status': 'must_do'},
    {'name': 'Fushimi Inari Taisha', 'city': 'Kyoto', 'area': 'Fushimi', 'category': 'landmark', 'status': 'confirmed', 'notes': 'Full hike takes about 2–3 hours. Bring water.'},
    {'name': 'Nishiki Market', 'city': 'Kyoto', 'area': 'Downtown', 'category': 'food', 'status': 'want_to_go', 'notes': '"Kyoto\'s Kitchen" — great street food and local pickles.'},
    {'name': 'Dotonbori', 'city': 'Osaka', 'area': 'Namba', 'category': 'food', 'status': 'want_to_go'},
    {'name': 'Osaka Castle', 'city': 'Osaka', 'area': 'Chuo', 'category': 'landmark', 'status': 'idea'},
    {'name': 'Harajuku Takeshita Street', 'city': 'Tokyo', 'area': 'Harajuku', 'category': 'shopping', 'status': 'want_to_go'},
    {'name': 'Kinkaku-ji (Golden Pavilion)', 'city': 'Kyoto', 'area': 'Kinkaku-ji', 'category': 'landmark', 'status': 'must_do'},
    {'name': 'Akihabara Electric Town', 'city': 'Tokyo', 'area': 'Akihabara', 'category': 'shopping', 'status': 'idea'},
  ];

  for (final s in spots) {
    await sb.from('spots').insert({
      'trip_id':  tripId,
      'name':     s['name'],
      'city':     s['city'],
      'area':     s['area'] ?? '',
      'category': s['category'],
      'status':   s['status'],
      if (s['notes'] != null) 'notes': s['notes'],
      'added_by': userId,
    });
  }
  print('  ${spots.length} spots');

  // ── Travel bookings ────────────────────────────────────────────────────────
  print('Seeding travel items …');
  final travelItems = [
    {
      'title': 'YYZ → NRT — Air Canada AC002',
      'type': 'flight',
      'status': 'booked',
      'date': _isoDate(startDate),
      'end_date': _isoDate(startDate.add(const Duration(days: 1))),
      'time': '22:30',
      'end_time': '02:45',
      'location': 'Toronto Pearson (YYZ)',
      'destination': 'Tokyo Narita (NRT)',
      'confirmation_number': 'AC-8842JKX',
    },
    {
      'title': 'Shinkansen — Tokyo to Kyoto',
      'type': 'train',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 5))),
      'time': '09:16',
      'end_time': '11:45',
      'location': 'Tokyo Station',
      'destination': 'Kyoto Station',
      'confirmation_number': 'JR-NOZOMI34',
    },
    {
      'title': 'Park Hyatt Tokyo',
      'type': 'hotel',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 1))),
      'end_date': _isoDate(startDate.add(const Duration(days: 5))),
      'destination': 'Shinjuku, Tokyo',
      'confirmation_number': 'PHT-20261203-W',
    },
    {
      'title': 'The Screen Kyoto',
      'type': 'hotel',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 5))),
      'end_date': _isoDate(startDate.add(const Duration(days: 9))),
      'destination': 'Kamigyo, Kyoto',
      'confirmation_number': 'SCR-KYO-44812',
    },
    {
      'title': 'Shinkansen — Kyoto to Osaka',
      'type': 'train',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 9))),
      'time': '10:00',
      'location': 'Kyoto Station',
      'destination': 'Shin-Osaka Station',
    },
    {
      'title': 'Osaka Airbnb — Namba',
      'type': 'hotel',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 9))),
      'end_date': _isoDate(startDate.add(const Duration(days: 12))),
      'destination': 'Namba, Osaka',
      'confirmation_number': 'ABNB-48291KL',
    },
    {
      'title': 'NRT → YYZ — Air Canada AC001',
      'type': 'flight',
      'status': 'booked',
      'date': _isoDate(endDate),
      'time': '10:45',
      'location': 'Tokyo Narita (NRT)',
      'destination': 'Toronto Pearson (YYZ)',
      'confirmation_number': 'AC-8843JKX',
    },
    {
      'title': 'teamLab Borderless Tickets',
      'type': 'ticket',
      'status': 'booked',
      'date': _isoDate(startDate.add(const Duration(days: 3))),
      'time': '14:00',
      'notes': '2 tickets — booking ref TLB-294812',
    },
  ];

  for (final t in travelItems) {
    await sb.from('travel_items').insert({
      'trip_id':    tripId,
      'created_by': userId,
      ...t,
    });
  }
  print('  ${travelItems.length} travel items');

  // ── Plan days & itinerary items ────────────────────────────────────────────
  print('Seeding plan days …');

  Future<String> addDay(int dayNum, DateTime date, String city, {String? notes}) async {
    final row = await sb.from('itinerary_days').insert({
      'trip_id':    tripId,
      'day_number': dayNum,
      'date':       _isoDate(date),
      'city':       city,
      'created_by': userId,
      if (notes != null) 'notes': notes,
    }).select().single();
    return row['id'] as String;
  }

  Future<void> addItem(String dayId, Map<String, dynamic> item) async {
    await sb.from('itinerary_items').insert({
      'trip_id':    tripId,
      'day_id':     dayId,
      'created_by': userId,
      ...item,
    });
  }

  // Day 1 — Arrival Tokyo
  final d1 = await addDay(1, startDate.add(const Duration(days: 1)), 'Tokyo', notes: 'Arrival day — easy start. Check in and explore Shinjuku.');
  await addItem(d1, {'title': 'Land at Narita (NRT)', 'type': 'travel', 'time': '02:45', 'sort_order': 0});
  await addItem(d1, {'title': 'Narita Express to Shinjuku', 'type': 'transport', 'time': '05:00', 'sort_order': 1});
  await addItem(d1, {'title': 'Check in — Park Hyatt Tokyo', 'type': 'other', 'time': '15:00', 'sort_order': 2});
  await addItem(d1, {'title': 'Dinner at Nishimura', 'type': 'food', 'time': '19:00', 'sort_order': 3, 'notes': 'Hotel restaurant — easy first night'});

  // Day 2 — Asakusa & Tsukiji
  final d2 = await addDay(2, startDate.add(const Duration(days: 2)), 'Tokyo');
  await addItem(d2, {'title': 'Tsukiji Outer Market breakfast', 'type': 'food', 'time': '07:30', 'sort_order': 0});
  await addItem(d2, {'title': 'Senso-ji Temple', 'type': 'spot', 'time': '10:00', 'sort_order': 1});
  await addItem(d2, {'title': 'Nakamise-dori shopping', 'type': 'activity', 'time': '11:30', 'sort_order': 2});
  await addItem(d2, {'title': 'Lunch — Asakusa Imahan', 'type': 'food', 'time': '13:00', 'sort_order': 3});
  await addItem(d2, {'title': 'Shibuya Crossing & Scramble', 'type': 'spot', 'time': '17:00', 'sort_order': 4});
  await addItem(d2, {'title': 'Shibuya drinks & dinner', 'type': 'food', 'time': '19:30', 'sort_order': 5});

  // Day 3 — teamLab + Harajuku
  final d3 = await addDay(3, startDate.add(const Duration(days: 3)), 'Tokyo');
  await addItem(d3, {'title': 'Harajuku Takeshita Street', 'type': 'spot', 'time': '10:00', 'sort_order': 0});
  await addItem(d3, {'title': 'Meiji Shrine', 'type': 'spot', 'time': '11:30', 'sort_order': 1});
  await addItem(d3, {'title': 'Lunch — Omotesando', 'type': 'food', 'time': '13:00', 'sort_order': 2});
  await addItem(d3, {'title': 'teamLab Borderless', 'type': 'activity', 'time': '14:00', 'sort_order': 3, 'notes': 'Tickets booked! Ref TLB-294812'});
  await addItem(d3, {'title': 'Odaiba waterfront walk', 'type': 'free_time', 'time': '17:30', 'sort_order': 4});

  // Day 4 — Akihabara + free
  final d4 = await addDay(4, startDate.add(const Duration(days: 4)), 'Tokyo');
  await addItem(d4, {'title': 'Akihabara Electric Town', 'type': 'spot', 'time': '10:00', 'sort_order': 0});
  await addItem(d4, {'title': 'Ueno Park & Museums', 'type': 'activity', 'time': '14:00', 'sort_order': 1});
  await addItem(d4, {'title': 'Shinkansen packing', 'type': 'other', 'time': '21:00', 'sort_order': 2});

  // Day 5 — Kyoto arrival
  final d5 = await addDay(5, startDate.add(const Duration(days: 5)), 'Kyoto');
  await addItem(d5, {'title': 'Shinkansen to Kyoto', 'type': 'travel', 'time': '09:16', 'sort_order': 0});
  await addItem(d5, {'title': 'Check in — The Screen', 'type': 'other', 'time': '13:00', 'sort_order': 1});
  await addItem(d5, {'title': 'Nishiki Market afternoon', 'type': 'spot', 'time': '14:30', 'sort_order': 2});
  await addItem(d5, {'title': 'Gion evening stroll', 'type': 'free_time', 'time': '18:00', 'sort_order': 3});

  // Day 6 — Arashiyama
  final d6 = await addDay(6, startDate.add(const Duration(days: 6)), 'Kyoto');
  await addItem(d6, {'title': 'Bamboo Grove early walk', 'type': 'spot', 'time': '07:00', 'sort_order': 0, 'notes': 'Go before 8am to beat crowds'});
  await addItem(d6, {'title': 'Tenryu-ji Temple', 'type': 'spot', 'time': '09:00', 'sort_order': 1});
  await addItem(d6, {'title': 'Sagano Scenic Railway', 'type': 'transport', 'time': '10:30', 'sort_order': 2});
  await addItem(d6, {'title': 'Lunch back in central Kyoto', 'type': 'food', 'time': '13:00', 'sort_order': 3});
  await addItem(d6, {'title': 'Kinkaku-ji (Golden Pavilion)', 'type': 'spot', 'time': '15:00', 'sort_order': 4});

  // Day 7 — Fushimi Inari
  final d7 = await addDay(7, startDate.add(const Duration(days: 7)), 'Kyoto');
  await addItem(d7, {'title': 'Fushimi Inari sunrise hike', 'type': 'spot', 'time': '06:30', 'sort_order': 0, 'notes': 'Pack water — 2–3hr full hike'});
  await addItem(d7, {'title': 'Nishimura Coffee & breakfast', 'type': 'food', 'time': '10:00', 'sort_order': 1});
  await addItem(d7, {'title': 'Philosopher\'s Path', 'type': 'spot', 'time': '12:00', 'sort_order': 2});
  await addItem(d7, {'title': 'Ginkaku-ji (Silver Pavilion)', 'type': 'spot', 'time': '13:30', 'sort_order': 3});
  await addItem(d7, {'title': 'Kaiseki dinner', 'type': 'food', 'time': '19:00', 'sort_order': 4, 'notes': 'Reservations at Mizai — 7pm sharp'});

  print('  7 plan days');

  // ── Receipts ───────────────────────────────────────────────────────────────
  print('Seeding receipts …');
  final receipts = [
    {'title': 'Tsukiji tuna bowl x2', 'amount': 3800.0, 'currency': 'JPY', 'home_amount': 34.20, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 2)))},
    {'title': 'Senso-ji temple soba', 'amount': 2200.0, 'currency': 'JPY', 'home_amount': 19.80, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 2)))},
    {'title': 'Nakamise souvenir shopping', 'amount': 8500.0, 'currency': 'JPY', 'home_amount': 76.50, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'shopping', 'date': _isoDate(startDate.add(const Duration(days: 2)))},
    {'title': 'Tokyo subway IC card top-up', 'amount': 5000.0, 'currency': 'JPY', 'home_amount': 45.00, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'transport', 'date': _isoDate(startDate.add(const Duration(days: 2)))},
    {'title': 'Shibuya ramen dinner', 'amount': 3600.0, 'currency': 'JPY', 'home_amount': 32.40, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 2)))},
    {'title': 'teamLab gift shop', 'amount': 4200.0, 'currency': 'JPY', 'home_amount': 37.80, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'shopping', 'date': _isoDate(startDate.add(const Duration(days: 3)))},
    {'title': 'Kyoto coffee & pastries', 'amount': 1800.0, 'currency': 'JPY', 'home_amount': 16.20, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 5)))},
    {'title': 'Nishiki Market snacks', 'amount': 2600.0, 'currency': 'JPY', 'home_amount': 23.40, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 5)))},
    {'title': 'Arashiyama rickshaw ride', 'amount': 6000.0, 'currency': 'JPY', 'home_amount': 54.00, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'activity', 'date': _isoDate(startDate.add(const Duration(days: 6)))},
    {'title': 'Kinkaku-ji entry tickets', 'amount': 800.0, 'currency': 'JPY', 'home_amount': 7.20, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'activity', 'date': _isoDate(startDate.add(const Duration(days: 6)))},
    {'title': 'Fushimi Inari shrine charms', 'amount': 1500.0, 'currency': 'JPY', 'home_amount': 13.50, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'shopping', 'date': _isoDate(startDate.add(const Duration(days: 7)))},
    {'title': 'Kaiseki dinner x2', 'amount': 28000.0, 'currency': 'JPY', 'home_amount': 252.00, 'exchange_rate': 0.009, 'paid_by': userId, 'category': 'food', 'date': _isoDate(startDate.add(const Duration(days: 7)))},
  ];

  for (final r in receipts) {
    await sb.from('receipts').insert({
      'trip_id':             tripId,
      'transaction_fee_pct': 0.0,
      ...r,
    });
  }
  print('  ${receipts.length} receipts');

  // ── Packing items ──────────────────────────────────────────────────────────
  print('Seeding packing items …');
  final packingItems = [
    // Documents
    'Passport', 'Travel insurance docs', 'JR Pass (printed)', 'Hotel confirmations printed',
    // Clothing
    'Comfortable walking shoes', 'Rain jacket', 'Light layers (Tokyo/Kyoto can be cool)', 'Formal outfit (kaiseki dinner)',
    // Tech
    'Universal power adapter (Japan is Type A)', 'Portable charger', 'Camera + extra SD cards', 'Noise-cancelling headphones',
    // Health & toiletries
    'Sunscreen SPF 50', 'Blister bandages', 'Travel size toiletries', 'Medications',
    // Money & misc
    'Cash JPY (¥50,000)', 'IC card (Suica)', 'Small backpack for day trips', 'Reusable shopping bag',
  ];

  for (int i = 0; i < packingItems.length; i++) {
    await sb.from('packing_items').insert({
      'trip_id':    tripId,
      'title':      packingItems[i],
      'created_by': userId,
      'sort_order': i,
      'is_packed':  i < 6, // first 6 items already packed
    });
  }
  print('  ${packingItems.length} packing items');

  // ── Shopping list ──────────────────────────────────────────────────────────
  print('Seeding shopping items …');
  final shoppingItems = [
    {'name': 'KitKat variety pack (airport)',    'quantity': '1 box'},
    {'name': 'Matcha KitKats',                   'quantity': '2 packs'},
    {'name': 'Pocky assorted',                   'quantity': '3–4 boxes'},
    {'name': 'Wagashi sweets (Nishiki Market)',   'quantity': null},
    {'name': 'Maneki-neko figurine',             'notes': 'For mom'},
    {'name': 'Daruma doll',                      'quantity': '1', 'notes': 'Small size'},
    {'name': 'Furoshiki wrapping cloth',         'notes': 'Traditional pattern'},
    {'name': 'Japanese stationery (Loft)',        'quantity': null},
    {'name': 'Tenugui hand towel',               'notes': 'Asakusa shop'},
    {'name': 'Sake to bring home',               'quantity': '2 bottles', 'notes': 'Check airline liquid rules'},
  ];

  for (int i = 0; i < shoppingItems.length; i++) {
    final item = shoppingItems[i];
    await sb.from('shopping_items').insert({
      'trip_id':    tripId,
      'name':       item['name'],
      'created_by': userId,
      'sort_order': i,
      'checked': i < 3, // first 3 already checked off
      if (item['quantity'] != null) 'quantity': item['quantity'],
      if (item['notes']    != null) 'notes':    item['notes'],
    });
  }
  print('  ${shoppingItems.length} shopping items');

  // ── Crew chat messages ─────────────────────────────────────────────────────
  print('Seeding crew chat messages …');
  final messages = [
    'This trip is going to be incredible 🎌',
    'I booked the kaiseki dinner at Mizai for night 7 — it was the last table!',
    'Should we get JR Passes before we leave or at the airport?',
    'Definitely get them before — cheaper online through JRPass.com',
    'I added the Arashiyama bamboo grove for Day 6 morning. Going early is key.',
    'Anyone know if we can bring sake back on the plane?',
    'Yes, just keep it under 2L per person and it needs to go in checked bags',
    'The Screen hotel looks AMAZING btw, great pick for Kyoto',
  ];

  for (final msg in messages) {
    await sb.from('trip_messages').insert({
      'trip_id':      tripId,
      'author_id':    userId,
      'message_type': 'text',
      'body':         msg,
    });
    await Future.delayed(const Duration(milliseconds: 50));
  }
  print('  ${messages.length} crew messages');

  // ── Done ───────────────────────────────────────────────────────────────────
  print('');
  print('✓ Demo data seeded!');
  print('  Trip: "Japan 2026" — starts ${_isoDate(startDate)}, ends ${_isoDate(endDate)}');
  print('  Pre-trip view will show the first travel booking and Day 1 plan.');
  print('');
  print('Hot-restart the app to see the changes.');

  await sb.auth.signOut();
  exit(0);
}

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
