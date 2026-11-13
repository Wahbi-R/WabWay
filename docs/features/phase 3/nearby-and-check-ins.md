# Nearby search & "Where's everyone?" check-ins (build 446)

## Nearby

**Where:** Spots app bar (near-me icon), More → Explore → Nearby, desktop sidebar → Nearby.
`lib/screens/nearby_screen.dart`, `lib/core/nearby_service.dart`.

- Gets the phone's location (`ensureLocationPermission` / `currentPosition(maxAge: 3 min)` from
  `lib/core/location/current_position.dart` — the same helpers Crew uses).
- Search box (keyboard "search" key) for anything: "ramen", "halal", "vegan", "Uniqlo".
- Shortcut chips (`kNearbyShortcuts`): Food, Coffee, Dessert, Bars, Konbini, ATM, Pharmacy,
  Toilets use Google **searchNearby** by type (popularity-ranked, hard radius); Ramen and Sushi
  are text searches.
- Filters sheet: within 500 m / 1 km / 1.5 km / 3 km / 5 km, Best match / Closest first,
  Open now, 4★ and up.
- Result card: photo, name, rating with stars + review count, price (`$$` or Google's
  price range), type, Open / Closes soon (< 1 h) / Closed, walking distance.
- Detail sheet: big photo, summary, address, today's hours (tap for the week — the phone
  picks today's line so the trip's local weekday is used, not the server's), phone, website,
  **Directions** (Google Maps place page) and **Save as spot**.
- Save as spot opens the normal Add spot sheet with `ImportPrefill(place: …)` — name,
  address, city, area, country, coordinates, category and place id are filled in; notes get
  "★ 4.4 (12k reviews) on Google · ¥1,000–¥2,000".

### Server (wabway-server)

- `POST /places/nearby` `{latitude, longitude, query? | kind?, radius, open_now, min_rating, rank}`
  → list of `{name, place_id, address, city, area, country, category, type_label, latitude,
  longitude, distance_m, rating, rating_count, price_level, price_range, open_now, closes_soon,
  weekday_hours, maps_url, website, phone, summary, photo_name}`.
  Text queries use searchText with a location bias and drop results > 1.5× the radius;
  `kind` uses searchNearby. Permanently/temporarily closed places are skipped.
  Needs the app's Supabase token; 120 searches per user per hour (rating/hours fields are the
  pricier Places tier).
- `GET /places/nearby/photo?name=…&w=…` → 302 to Google's CDN (no key in the URL), cached in
  memory. Needs the Supabase token (sent as an image header by the app).

## "Where's everyone?" (Crew)

For malls, stations and markets: GPS puts everyone on the same pin and can't tell floors
apart, so people say where they are instead. `lib/screens/crew/whereabouts.dart`.

- **I'm at…** (Crew chat, above Find Me) → sheet: Place (required), Floor, Next to, optional
  camera photo of what's around, optional "Add a map pin too". Sent as a `check_in` message:
  body "Uniqlo · 3F · near the escalators", photo in `image_url` (trip-chat bucket), lat/lng
  only when the pin was asked for. Crew gets a push ("📍 Sam is at Uniqlo · 3F").
- **Where's everyone?** → `where_ask` message + push ("👀 Sam: where is everyone?"). The card
  shows **Say where I am** to everyone else, and "You checked in" once they have.
- **Who's where** strip on top of the chat (when someone checked in or asked in the last 3 h):
  your own tile ("I'm at…" or your latest), then everyone's latest check-in; tap for the photo
  and the Navigate-to-pin button.
- Migration `055_crew_check_ins.sql` adds `check_in` and `where_ask` to
  `trip_messages_message_type_check`. Older app versions show them as plain text messages.

## Ideas not done

- Bluetooth "who's close" (phones seeing each other's BLE signal) — needs native
  advertising + scanning plugins and Android 12 nearby-devices permission.
- Marking Nearby results already saved as spots.
