import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// ─── Changelog entries ────────────────────────────────────────────────────────
// Add newest entry at the top. Max ~20 shown in the sheet.

const _kChangelog = <_Release>[
  _Release(
    version: '1.1.0',
    build: 308,
    label: 'Fix: stable day ordering when dates overlap',
    changes: [
      'Days sharing the same date now always display in a consistent, stable order',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 307,
    label: 'Fix: connection chips and stay-swap picker',
    changes: [
      'Spot connection chips no longer show a tap effect when tapping them does nothing',
      'Swapping a stay-filled plan item now opens the picker on the Stay tab directly',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 306,
    label: 'Fix: plan cache round-trip (type + stay link)',
    changes: [
      'Itinerary items loaded from offline cache now keep their correct type (e.g. Stay, Food, Free Time) instead of falling back to Other',
      'Stays linked to a plan item are now preserved when loading from cache',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 305,
    label: 'Fix: Add Day dialog date initialisation',
    changes: [
      'Fixed a crash that could occur when opening the Add Day dialog in the itinerary planner',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 304,
    label: 'Spots: Stays filter, connections on stays',
    changes: [
      'Filter the Spots list to show only your accommodations using the new "Stays" chip',
      'Tapping a stay from the Spots screen now shows a proper sheet with check-in/out details',
      'You can now link documents and spots to a stay from the stay sheet or the accommodation edit screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 303,
    label: 'Plan: chronological day numbers, duplicate dates allowed',
    changes: [
      'Day numbers in the itinerary now always reflect date order — Day 1 is your earliest date, Day 2 is the next, and so on',
      'You can now add two days on the same date (e.g. Tokyo in the morning and Kyoto in the evening on Aug 19)',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 302,
    label: 'Plan: Stay items, fix delete cache, fill from stay',
    changes: [
      'Deleting a day now immediately updates the offline cache — deleted days no longer reappear when you pull to refresh',
      'New "Stay" item type in the itinerary — add your booked accommodations directly to the plan',
      '"Add itinerary item" now shows a "Fill from spot or stay" picker with a Spots / Stays tab, so you can fill from an accommodation in one tap',
      'Linking a stay to a plan item creates a proper connection — tap the linked stay chip in item details to see its info',
      'Spot address no longer shows as the item subtitle — the name is already the title, so the address was redundant',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 301,
    label: 'Fix: spots screen fully clears on trip switch',
    changes: [
      'Switching trips on the Spots screen now immediately clears stay suggestions and your vote state — previously they could linger from the previous trip if the load failed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 300,
    label: 'Plan: days sorted oldest-first, bulk "Add all days" button',
    changes: [
      'Day 1 is always at the top — days are now sorted by date regardless of the order you added them',
      'New "Add all days" button fills every date in your trip\'s date range at once, skipping days you\'ve already added',
      'Adding a day after deleting one no longer creates duplicate day numbers',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 299,
    label: 'Plan: Add Day defaults to the next sequential date',
    changes: [
      'The date picker now opens on the day after your latest itinerary day — if you have Nov 6 it suggests Nov 7 automatically',
      'For a new trip with no days yet, the picker opens on your trip\'s start date instead of today',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 298,
    label: 'Fix: switching trips never shows the previous trip\'s data',
    changes: [
      'All screens now clear their lists immediately when switching trips — if the network is unavailable you\'ll see the offline state rather than the wrong trip\'s content',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 297,
    label: 'Fix: shopping realtime no longer connects before trip loads',
    changes: [
      'The shopping list no longer opens a realtime connection before your trip data is ready on startup',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 296,
    label: 'Fix: shopping list stays responsive when switching trips',
    changes: [
      'Switching trips no longer risks freezing the shopping list spinner — a stale background timer is now cancelled before the new trip loads',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 295,
    label: 'Fix: votes and settlements preserved in cached view',
    changes: [
      'Your vote on a spot is now shown correctly even before the network refreshes — the cached view no longer clears it',
      'Settle Up balances are no longer lost if a network reload fails on the same trip',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 294,
    label: 'Fix: packing list loads correctly on first launch',
    changes: [
      'The packing list no longer issues a spurious empty-trip network request before your trip data has loaded',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 293,
    label: 'Fix: global search & map survive accommodation errors',
    changes: [
      'Global search and the map no longer fail entirely when accommodation data can\'t be fetched — spots, docs, and all other results still load normally',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 292,
    label: 'Fix: safer offline cache reads for plan & travel',
    changes: [
      'Plan and Travel items with an unrecognised type in the offline cache now fall back to "other" instead of crashing — corrupted or renamed cache entries are handled gracefully',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 291,
    label: 'Fix: lint cleanup in accommodation service',
    changes: [
      'Minor internal code quality fix — no user-facing changes',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 290,
    label: 'Fix: connection panel stability on poor connections',
    changes: [
      'The connections panel (links between spots, stays, travel, etc.) no longer crashes when accommodation data can\'t be fetched — it shows whatever it has and skips the missing stays gracefully',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 289,
    label: 'Offline reliability: faster cache & safer spot loading',
    changes: [
      'The Plan and Travel screens now load cached data faster — all three data sources fetch at the same time instead of one after another',
      'The Spots screen now loads successfully even when there\'s a temporary problem fetching accommodations — spots and docs always appear',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 288,
    label: 'Fix: notifications from web',
    changes: [
      'Messages and updates sent from the WabWay web app now correctly notify your phone — previously no push notifications were sent when acting from a browser',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 287,
    label: 'Offline reliability: accommodation fallback',
    changes: [
      'Loading accommodations now falls back to cached data on a network error instead of crashing — no more blank screens when your connection drops mid-load',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 286,
    label: 'Offline caching reliability fixes',
    changes: [
      'Switching trips no longer briefly shows spots, docs, or money settlements from your previous trip',
      'Shopping list now stays in sync with real-time updates after switching trips',
      'Offline cache is guaranteed to be saved before the screen updates, preventing missed cache reads on fast revisits',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 285,
    label: 'SWR test suite green',
    changes: [
      'All offline-caching behaviours verified by automated integration tests: cache-first, trip-switch invalidation, rapid-tab gen-counter, and warm-cache spinner timing',
      'Fixed visual glitches on the Home screen caused by missing Material wrappers around list tiles',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 284,
    label: 'Instant offline browsing',
    changes: [
      'Spots, docs, money, plan, travel, accommodations, shopping, and packing all load instantly from cache while a fresh sync runs in the background',
      'Switching trips or tabs no longer shows a spinner when data was previously loaded',
      'Real-time updates from teammates no longer cause flicker — stale results are silently dropped',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 283,
    label: 'Send photos in crew chat',
    changes: [
      'Tap the new image button in crew chat to share a photo from your camera or photo library',
      'Images appear as 220×220 thumbnails in the chat alongside text and location messages',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 282,
    label: 'Anyone can invite trip members',
    changes: [
      'Any trip member (not just the owner) can now create and share invite codes',
      'The Invite section is now visible in the More screen for all members',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 281,
    label: 'Spot city & area from all import flows',
    changes: [
      'Spots imported via video share, Maps link, or CSV now correctly show their neighbourhood / area alongside the city',
      'Area is now sourced from Google Places (sublocality/neighborhood) and Nominatim (suburb/quarter) on every import path that supports it',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 280,
    label: 'Links: connected to the whole trip',
    changes: [
      'Spots, shopping items, itinerary, travel bookings, and accommodations with a link now appear as dedicated sections in the Links screen',
      'Tap any entry to open its URL — sections only appear when items actually have links set',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 279,
    label: 'Map auto-fit fix',
    changes: [
      'Map now correctly fits to your spots on first open even when starting with an empty trip',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 276,
    label: 'Add spot: better city & area fill',
    changes: [
      'Searching for a place now auto-fills the city and neighbourhood area fields',
      'Existing city/area values are kept when the search result has no data for them',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 275,
    label: 'Video spot import fixes',
    changes: [
      'Places from video with missing coordinates now still get looked up instead of disappearing',
      'Spot photos from video sharing now load on web too',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 274,
    label: 'Map spot improvements',
    changes: [
      'Spot details on the map no longer clip — everything scrolls fully',
      'You can now delete a spot directly from the map bottom sheet',
      'Spot detail has a "Show on map" button that opens the map centred on that spot',
      '"Open in Maps" button renamed to "Open in Maps app" to be clearer',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 273,
    label: 'Better spot photos from video',
    changes: [
      'Spots added from video sharing now use real Google Maps photos',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 272,
    label: 'Smarter video spot import',
    changes: [
      'Video sharing now uses AI to identify restaurant and place names accurately',
      'Spots found from videos are looked up via Google Maps for better results',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 271,
    label: 'Reliability fixes',
    changes: [
      'Sign-out now reliably works even if a network error occurs mid-logout',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 270,
    label: 'Faster image loading',
    changes: [
      'Cached photos now load up to 8× faster thanks to a new storage engine',
      'Your device can now cache up to 600 photos (up from 150)',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 269,
    label: 'Full offline mode',
    changes: [
      'Photos now load from your device cache when you\'re offline',
      'Your crew members are remembered offline so money splits still show everyone',
      'Receipts saved while offline are automatically synced when you reconnect',
      'The app reconnects silently in the background — no more manual retry needed',
      'Offline banner now appears at the trip level, not just inside each screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 268,
    label: 'Works offline',
    changes: [
      'The app no longer gets stuck on the splash screen when opened without internet',
      'Your trips and profile load from cache so you can browse offline after your first online session',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 267,
    label: 'Map: current location button',
    changes: [
      'Tap the location button on the map to instantly jump to where you are',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 266,
    label: 'Map now shows English labels',
    changes: [
      'Map labels now appear in English worldwide instead of the local language',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 265,
    label: 'Fix: OSM attribution added to map',
    changes: [
      'OpenStreetMap attribution is shown in the corner of the map as required',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 264,
    label: 'Fix: map no longer shows API key watermark',
    changes: [
      'The map now loads cleanly without the "API KEY REQUIRED" watermark',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 263,
    label: 'Spots: editing adds missing photos',
    changes: [
      'If a spot has no photo, editing it and saving will now automatically fetch one from Google Places',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 262,
    label: 'Bug fix: multi-select delete',
    changes: [
      'Fixed a rare crash that could occur when deleting spots that had been removed by another trip member during your session',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 261,
    label: 'Multi-select delete on Spots',
    changes: [
      'Long-press any spot to enter selection mode — then tap others to add them to the selection',
      'Tap the delete button in the toolbar to remove all selected spots at once',
      'Works on both mobile and desktop',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 260,
    label: 'CSV import — spots now get photos',
    changes: [
      'Spots imported from a Google Maps CSV now pick up photos, just like manually added spots',
      'Photos come from Google Places (via wabway-server), with Wikipedia as a fallback on the Android app',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 259,
    label: 'Documents — any member can rename',
    changes: [
      'Any trip member can now rename a shared document, not just the person who uploaded it',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 258,
    label: 'Spot notification toggle',
    changes: [
      'Adding a spot now has a "Notify crew" switch — turn it off to add spots in bulk without pinging everyone',
      'The toggle remembers your last choice across adds',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 257,
    label: 'Smarter spot category',
    changes: [
      'Category now auto-fills correctly when you pick a place from search',
      'When the category can\'t be determined from the place type, AI suggests the best match in the background',
      'Submitting without a category selected now scrolls you directly to the category field',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 256,
    label: 'Unified connections',
    changes: [
      'Spots linked to plan items now appear in the Connected section with full navigation and remove support',
      'Linking a spot when creating or editing a plan item goes through the same connections system as everything else',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 255,
    label: 'Connections everywhere',
    changes: [
      'Plan items now have a "Connected" section — link them to spots, docs, travel, stays, and links',
      'Documents now have a "Connected" section — link them to other trip entities',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 254,
    label: 'Cross-section linking',
    changes: [
      'Spots and travel items now have a "Connected" section — link them to documents, stays, plan items, links, and more',
      'Tap any connection chip to jump straight to that item',
      'Tap "Add" to open a picker and browse the trip\'s entities by type',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 252,
    label: 'Per-person packing',
    changes: [
      'Packing list now lets every crew member check off their own copy of each item — tap your checkbox, see everyone else\'s dots fill in as they pack',
      'Each item shows a row of small avatar circles so you can see at a glance who\'s packed and who hasn\'t',
      'Progress bar tracks your personal count, not a shared one',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 251,
    label: 'Smarter "Add to itinerary"',
    changes: [
      '"Add to itinerary" on a travel item now pre-selects the plan day that matches the item\'s date',
      'Departure time is pre-filled so you don\'t have to set it manually',
      'If you want a different day, the suggested one is still badged so it\'s easy to spot',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 250,
    label: 'Tappable First Up & spot dots',
    changes: [
      'Tap a First Up item on the home screen to jump straight to the travel or plan item detail',
      'Spots now show a small colored dot by category — terracotta for food, sage for nature & landmarks, gold for experiences & shopping',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 249,
    label: 'UI polish',
    changes: [
      'Crew chat now shows a circular avatar beside every message bubble',
      'Settle Up screen is properly centred when all balances are cleared',
      'Settle Up on desktop now fills the full width instead of a narrow column',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 248,
    label: 'Boarding pass scan',
    changes: [
      'Scan your boarding pass on a flight to auto-fill terminal, gate, seat, and departure time',
      'Departure and arrival terminal fields on all transport items',
      'Gate and seat number fields so everything is in one place',
      'Boarding time shown separately from departure time so you never miss boarding',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 247,
    label: 'Travel types & plan progress',
    changes: [
      'Travel now has Flight, Train, Bus, Ferry, and Car — more ways to log how you\'re getting around',
      'Plan progress bar shows at the top of your itinerary so you always know how many items are done',
      'Bus and ferry journeys show departure/arrival fields just like flights and trains',
      'Car rentals show pick-up and return date/time fields',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 246,
    label: 'UI polish',
    changes: [
      'Home screen title is bolder and easier to read at a glance',
      'Balance chips now show name and amount on separate lines for clearer scanning',
      'More screen Explore section is now a compact 4-column icon grid',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 245,
    label: 'Lucide icons in toolbar',
    changes: [
      'Chat, search, and notifications icons updated to crisp Lucide-style line art',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 244,
    label: 'Home screen polish',
    changes: [
      'Balances now shows a chip per person — tap into Money for the full breakdown',
      'Stats row no longer truncates — labels are shorter and cleaner',
      '"First up" always shows the correct next day\'s first item',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 243,
    label: 'Bug fixes',
    changes: [
      'Update available banner no longer appears on local debug builds',
      'The Add Day form no longer overflows when the keyboard is open — it now scrolls',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 242,
    label: 'Home: smarter pre-trip view',
    changes: [
      'The trip card now shows a "First up" preview — your next travel booking and first planned itinerary item — before the trip starts',
      'Spots stat on the home card changes from "Spots visited" to "Spots saved" in the planning phase',
      'The separate "Coming up" card is hidden pre-trip since that info now lives inside the trip card itself',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 197,
    label: 'Scan & split receipt items',
    changes: [
      'Add Receipt now has a "Scan receipt" button — snap a photo and the app reads the line items automatically',
      'Tap each person\'s name on the item list to show who had what; tax and tip are split proportionally',
      'The total and per-person amounts fill in automatically — works with any currency',
      'If the server is unavailable the form still works exactly as before, nothing breaks',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 196,
    label: 'Shopping: links & image previews',
    changes: [
      'Shopping items now support a link — paste a product URL and the item will automatically pull in the page\'s preview image',
      'Linked items show a thumbnail on the list and a full image preview in the edit sheet (with option to clear it)',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 195,
    label: 'Find Me auto-shares location',
    changes: [
      'Tapping Find Me now automatically turns on live location sharing, so your crew\'s map pin stays up to date while they navigate to you',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 194,
    label: 'Web fixes & date picker improvements',
    changes: [
      'Creating a trip no longer gets stuck on a loading spinner — it navigates straight into the trip',
      'Trip Settings and Invite codes sheets no longer scroll to infinity on web',
      'Delete / Leave trip now appears in the desktop Settings panel, not just the mobile More tab',
      'Picking trip dates, accommodation dates, and member arrival/departure now opens a single range picker so you choose both dates in one step',
      'Create trip currency fields are now dropdowns with clear labels — Spending currency (what you\'ll spend abroad) and Settlement currency (what you pay each other back in); includes an "Other" option for any 3-letter code',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 193,
    label: 'Under the hood — stability fix',
    changes: [
      'Fixed a startup timing issue where the app could log a provider error on the first frame',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 190,
    label: 'Under the hood — automated tests',
    changes: [
      'Added automated integration tests that verify every screen loads without crashing',
      'Two-client sync tests confirm packing list and crew chat update in real-time between mobile and browser',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 189,
    label: 'Under the hood — stability improvements',
    changes: [
      'All screens now load trip and profile data from a single reactive source',
      'Switching trips refreshes every screen instantly without restarting the app',
      'Eliminates a class of crashes that could occur when navigating quickly after launch',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 188,
    label: 'Shopping list',
    changes: [
      'Add a shared shopping list from the More tab (or Shopping in the sidebar)',
      'Type an item name and tap + to add it instantly, or use the tune icon for quantity, notes, and a linked spot',
      'Check off items as you shop — checked items move to a separate section',
      'Swipe left on any item to delete it, or clear all checked items at once',
      'Everyone on the trip sees changes live thanks to real-time sync',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 187,
    label: 'Link stays to spots',
    changes: [
      'Open any stay and tap "Linked spot" to connect it to one of your trip spots',
      'The spot detail now shows a "Linked stay" card with dates and booking status',
      'Stay detail sheets show the linked spot name and status',
      'Remove a link any time from the edit form — no data is deleted',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 186,
    label: 'Stays in Spots screen',
    changes: [
      'Accommodations now appear below the spots list in the Spots screen',
      'Tap any stay to see its name, status, check-in/out dates, and address',
      'Stays are grouped under a "Stays" section header with a hotel icon',
      'Each stay shows a color-coded icon based on its booking status',
      'New stays and updates appear in real time — no refresh needed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 185,
    label: 'Plan: calendar view',
    changes: [
      'Tap the calendar icon in the Plan screen to switch to a month-grid view',
      'Days with planned items show coloured dots — one per activity type',
      'Tap any date to see its items with checkboxes and a quick Add button',
      'Tap an item to open its full details, just like in list mode',
      'Navigate months with the arrow buttons; switch back to list any time',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 184,
    label: 'Stays now appear on the map',
    changes: [
      'Accommodations with an address now show as hotel markers on the Map screen',
      'Tap a stay marker to see its name, status, check-in/check-out dates, and address',
      'List view shows stays grouped by whether they have coordinates or not',
      'Map camera automatically fits to include both spots and stays',
      'New stays update the map in real time — no refresh needed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 183,
    label: 'Fix: crew chat + members update live',
    changes: [
      'Crew chat messages now appear immediately after you send them — no more leaving and re-entering',
      'New trip members now show up without restarting the app',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 182,
    label: 'Add Spot: address search + UX polish',
    changes: [
      'The Add Spot button is no longer hidden behind your phone\'s home/back bar',
      'Category auto-selects when you pick a place from search — with smart name-based guessing as a fallback',
      'Address field now has a search icon: type any address and tap 🔍 to look it up and fill in coordinates',
      'Searching a place now keeps the name visible in the search field after you select it',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 181,
    label: 'Fix: Find Me SOS now works',
    changes: [
      'The Find Me SOS button no longer shows "Could not get location" — a database constraint was blocking the alert message from being saved',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 180,
    label: 'Fix: push notifications now deliver',
    changes: [
      'Push notifications (crew messages, location sharing, Find Me) now reach your device reliably — a server-side JWT encoding bug was silently dropping every notification',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 179,
    label: 'Fix: location sharing crash when GPS off',
    changes: [
      'Starting location sharing with GPS disabled no longer crashes — the app now shows a helpful message and opens Location Settings instead',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 178,
    label: 'Money: clear all filters at once',
    changes: [
      'A "Clear filters" chip now appears in the Receipts tab whenever any filter is active — tap it to reset category, payer, date range, and search in one go',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 177,
    label: 'Docs: share your document list',
    changes: [
      'Tap the share icon in the Documents screen to send your document list as formatted text — grouped by type with title, amount, and notes',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 176,
    label: 'Links: share your link list',
    changes: [
      'Tap the share icon in the Links screen to send your full link collection as a formatted list — grouped by category with title, URL, and notes for easy sharing',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 175,
    label: 'Stays: export to CSV',
    changes: [
      'Tap the share icon in the Stays screen to export all your accommodation details (check-in/out, price, confirmation number, and more) as a CSV file',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 174,
    label: 'Spots: sort by city',
    changes: [
      'Choose "By city" in the spots sort menu to group all your spots by location — handy for planning which areas to hit each day',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 173,
    label: 'Packing: pack all items at once',
    changes: [
      'Tap "Pack all items" from the packing menu to mark every remaining item as packed in one go — great for those final checks before heading to the airport',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 172,
    label: 'Spots: quick-filter by status',
    changes: [
      'Filter chips for each status (Idea, Want to go, Visited…) now appear below the category strip — tap one or more to narrow the list without opening the filter sheet',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 171,
    label: 'Packing: share your list with the crew',
    changes: [
      'Tap the menu on the Packing screen and choose Share list to send your full packing checklist — unpacked items show □, packed items show ✓',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 170,
    label: 'Plan: collapse or expand all days at once',
    changes: [
      'A single tap on the collapse button in the Plan toolbar folds every day card at once — instantly see the full trip outline without scrolling',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 169,
    label: 'Plan: collapse individual day cards',
    changes: [
      'Tap the chevron on any day card to collapse its items — great for scanning all days at once on a long trip',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 168,
    label: 'Money: swipe receipt left to delete',
    changes: [
      'Swipe a receipt left to delete it without opening the detail screen — consistent with Travel, Stays, and Links',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 167,
    label: 'Money: filter receipts by payer on mobile',
    changes: [
      'The "filter by who paid" chip row now appears on the mobile Receipts tab — tap a person to see only their expenses',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 166,
    label: 'Travel: swipe left to delete',
    changes: [
      'Swipe any travel card left to remove it instantly — no need to open the detail screen to delete a booking',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 165,
    label: 'Links: swipe left to delete',
    changes: [
      'Swipe a link card left to remove it instantly — no confirmation dialog, with a snackbar so you know it worked',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 164,
    label: 'Stays: swipe left to delete',
    changes: [
      'Swipe a stay card left to delete it — no need to open the detail sheet just to remove a booking',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 163,
    label: 'Spots: visited progress bar on desktop',
    changes: [
      'The "X of Y spots visited" progress bar now appears in the desktop spots panel, matching the mobile view',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 162,
    label: 'Money: search cash withdrawals',
    changes: [
      'A search bar now appears on the Cash tab — find any ATM withdrawal by currency, amount, or notes instantly',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 161,
    label: 'Docs: filter by who uploaded',
    changes: [
      'A new filter row appears in Documents when the trip has uploads from multiple people — tap a name to see only their files',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 160,
    label: 'Travel: export itinerary as CSV',
    changes: [
      'A share button in Travel lets you export your bookings as a CSV — filtered results only, so you can share just your flights, just your hotels, etc.',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 159,
    label: 'Plan: pick which day when adding an item',
    changes: [
      '"Add item" now asks which day when your trip has multiple days — no more items silently added to the last day',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 158,
    label: 'Packing: swipe to pack',
    changes: [
      'Swipe right on any packing item to instantly toggle it packed or unpacked — a check icon confirms packing, undo confirms unpacking',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 157,
    label: 'Search: cash withdrawals included',
    changes: [
      'Global search now includes cash withdrawals — search by currency, amount, or ATM notes to find any withdrawal instantly',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 156,
    label: 'Stays: sort by date, name, or newest',
    changes: [
      'A sort button now appears on the Stays screen — sort by check-in date (default), A – Z, or newest added',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 155,
    label: 'Home: spot progress + richer upcoming',
    changes: [
      'The "Spots visited" counter on the home screen now shows "X/Y" so you can see your visit progress at a glance',
      '"Coming up" now shows up to three upcoming plan days and travel bookings side by side, sorted by date',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 154,
    label: 'Money: cash summary + sort',
    changes: [
      'The Cash tab now shows a summary card with total withdrawn per currency and ATM fees when you have two or more withdrawals',
      'A sort button lets you switch between "Newest first" and "Oldest first" on the Cash tab',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 153,
    label: 'Plan: copy day as text',
    changes: [
      'Tap ··· on any day card and choose "Copy day as text" to copy a formatted itinerary to your clipboard — paste it into messages to share with the group',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 152,
    label: 'Links: sort by date or title',
    changes: [
      'A sort button now appears in the Links screen — choose "Newest first", "Oldest first", or "A – Z"',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 151,
    label: 'Docs: sort by newest, A–Z, or type',
    changes: [
      'A sort button now appears in the Documents screen — choose "Newest first", "A – Z", or "By type"',
      'The icon turns blue when a non-default sort is active so you always know what\'s applied',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 150,
    label: 'Travel: filter by booking status',
    changes: [
      'New status chips below the type filter — tap "Tentative" to see what still needs confirming, "Cancelled" to see what fell through',
      'Chips only appear when you have items with more than one booking status',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 149,
    label: 'Plan: swipe to check off items',
    changes: [
      'Swipe right on any plan item to mark it done — a tick icon slides in from the left',
      'Swipe right again on a completed item to uncheck it',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 148,
    label: 'Money: quick date filter presets',
    changes: [
      '"Today", "This week", and "This month" chips now appear under the receipt filters — tap one to instantly narrow the list to that time window, tap again to clear',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 147,
    label: 'Spots: visited progress bar',
    changes: [
      'A slim progress bar now appears below the category chips on the Spots screen showing how many spots you\'ve visited out of the ones shown',
      'The bar and label turn green when every spot in the current view has been visited',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 146,
    label: 'Home: today\'s bookings in agenda',
    changes: [
      'If you have a flight, hotel check-in, or any other booking today, it now appears in a "Bookings today" section at the bottom of the Today card on the home screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 145,
    label: 'Plan: day time span in card header',
    changes: [
      'When two or more items on a day have a time set, the day card now shows a "09:00 → 21:00" time range in the header — a quick glance at how packed the day is',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 144,
    label: 'Plan: trip progress bar',
    changes: [
      'A progress bar now appears on the Plan screen once you start checking off items — shows "X of Y done" with a percentage so you can see how the day (or whole trip) is going at a glance',
      'The bar turns green when every item across all days is complete',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 143,
    label: 'Packing: add multiple items at once',
    changes: [
      'The packing list "Add item" dialog now accepts comma-separated input — type "Passport, charger, adapter" and all three are added in one step',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 142,
    label: 'Travel: jump to today',
    changes: [
      'A calendar icon now appears in the Travel screen when you have a booking on today\'s date — tap it to scroll straight to today\'s items',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 141,
    label: 'Plan: hide completed items',
    changes: [
      'Tap the eye icon in the Plan screen to hide all checked-off items — useful on active trip days when you just want to see what\'s still ahead',
      'Tap again to reveal completed items; the button turns teal to remind you that some items are hidden',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 140,
    label: 'Money: daily average spend',
    changes: [
      'The spending summary now shows your average daily spend next to the trip total — helps you see whether you\'re pacing within your budget',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 139,
    label: 'Plan: per-day cost totals',
    changes: [
      'Each plan day now shows the total planned cost for that day right in the day header — great for checking your daily budget at a glance',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 138,
    label: 'Plan: jump to today',
    changes: [
      'A "today" button now appears in the plan screen when your trip has a day matching today — tap it to jump straight to today\'s schedule without scrolling',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 137,
    label: 'Travel: date-grouped timeline',
    changes: [
      'Travel items are now grouped by date with a clear header for each day — the list reads like a trip timeline instead of a flat pile',
      '"Today" and "Tomorrow" labels highlight the most relevant bookings at a glance',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 136,
    label: 'Plan: budget summary',
    changes: [
      'The plan screen now shows a "Planned" total at the top — costs are summed per currency across every day so you can see your budget at a glance',
      'Opening a plan item now shows its estimated cost in the details card',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 135,
    label: 'Travel: smarter itinerary link',
    changes: [
      'Adding a travel item to the itinerary now also saves the link back to the booking — the "In plan" badge appears on the card right away without needing a refresh',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 134,
    label: 'Travel: plan + doc badges',
    changes: [
      'Travel item cards now show an "In plan" badge when that booking is already on your itinerary — so you never add a flight or hotel twice',
      'A purple doc badge shows how many documents are linked — quick confirmation that your boarding pass or hotel voucher is attached',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 133,
    label: 'Plan items: attach documents',
    changes: [
      'Tap "Attach Document" on any plan item to link trip documents directly — meeting notes, tickets, confirmations — so everything for a day\'s activity is in one place',
      'Already-linked documents are pre-checked so adding or removing a link is a single tap',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 132,
    label: 'Travel: attach documents',
    changes: [
      'Tap "Attach document" on a travel item to link any trip document — boarding passes, booking confirmations, hotel vouchers — directly to that item',
      'Previously linked documents are pre-selected, so you can add or remove links in one step',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 131,
    label: 'Travel: add to itinerary',
    changes: [
      'Tap "Add to itinerary" on any travel item to drop it straight into a plan day — pick the day and time from the same sheet used everywhere else',
      'Flights and trains land as Travel / Transport items; tickets become Activities — types are mapped automatically so your itinerary stays organised',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 130,
    label: 'Travel: booking URL',
    changes: [
      'Add a booking URL to any travel item (flight, hotel, rail pass, etc.) and tap "Open booking" to go straight to the airline or hotel manage-booking page',
      'Works for any booking that has a web page — great for checking in or making seat changes on the go',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 129,
    label: 'Spots: quick status from list',
    changes: [
      'Long-press any spot to mark it visited, skip it, or reset it — no need to open the full detail',
      'Plan item comments now show real names instead of garbled IDs',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 128,
    label: 'Plan item: tappable links',
    changes: [
      'Google Maps and confirmation links on plan items now show "Open →" and open in your browser — no more "Link available" dead end',
      'Tapping the linked spot card now opens the full Spot detail screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 127,
    label: 'Home: Spots visited count',
    changes: [
      'The trip hero now shows how many spots you\'ve actually visited — not just how many are on the list',
      'Gives a quick at-a-glance sense of trip progress as you check places off',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 126,
    label: 'Packing list: "Mine only" filter',
    changes: [
      'Tap "Mine only" on the packing list to see just the items assigned to you — no more scrolling through everyone else\'s gear',
      'The chip appears automatically once someone assigns items in the group',
      'Drag-to-reorder handles hide while filtering, so the list stays easy to scan',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 125,
    label: 'Map: long-press to add a spot',
    changes: [
      'Long-press anywhere on the Map to open the Add Spot form — the tapped coordinates are pre-filled',
      'The "Map ready" indicator appears immediately so you know exactly where the pin will land',
      'Save the spot and it drops onto the map right away',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 124,
    label: 'Travel: past booking labels',
    changes: [
      'Completed travel items (departure in the past) now appear dimmed so upcoming bookings stand out',
      'The countdown label switches to "Yesterday" or "N days ago" in muted grey once a booking has passed',
      'Cancelled items are unchanged',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 123,
    label: 'Receipt "Paid by" filter',
    changes: [
      'In the Money tab, filter receipts by who paid — tap a crew member\'s name chip to see only their receipts',
      'Stacks with the category filter, date range, search, and sort — narrow down any combination',
      'Only appears when more than one person has paid a receipt, so solo trips stay clutter-free',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 122,
    label: 'Stays improvements',
    changes: [
      'Stays are now fully connected to your shared trip — everything you save is visible to the whole crew in real time',
      'Add a confirmation number when booking a stay — it appears on the card and you can copy it with one tap',
      'Tap "Open booking →" on any card that has a URL to jump straight to the listing',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 121,
    label: 'Crew chat reactions',
    changes: [
      'Long-press any crew message to react with an emoji (❤️ 👍 😂 😮 😢 🔥)',
      'Reaction counts appear below the bubble — tap one to add or remove your own reaction',
      'Reactions are synced in real time, so the whole crew sees them instantly',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 120,
    label: 'Packing list progress & templates',
    changes: [
      'A progress bar at the top of the packing list shows how many items are packed — and turns green when everything is done',
      'New "Add from template" option (overflow menu or empty state) lets you pick common travel items across 6 categories without typing each one',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 119,
    label: 'Open email app from sign-in',
    changes: [
      'After sending a magic link or password-reset email, an "Open email app" button now appears so you can jump straight to your inbox without leaving WabWay',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 118,
    label: 'Bigger SOS button + high-priority alert',
    changes: [
      'The "Find Me" SOS button is now a large, always-visible red button at the bottom of the crew chat — impossible to miss when you need it',
      'Tapping it asks you to confirm before alerting everyone, so accidental presses don\'t bother the crew',
      'When you send an SOS your crewmates receive a high-priority push notification that bypasses silent mode on both Android and iOS',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 117,
    label: 'Update prompt now shows before login',
    changes: [
      'If a new version of WabWay is available, you\'ll now see the update prompt on the sign-in screen and the "no trips" screen — not just after you\'ve loaded your trip',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 116,
    label: 'Invite links + Android banner',
    changes: [
      'You can now share a direct invite link from the Invite Codes sheet — anyone who taps it gets taken straight to the join screen with the code pre-filled',
      'New members who sign up via an invite link are automatically shown the join sheet after creating their account — no need to re-enter the code',
      'If you open WabWay in a browser on Android, a small banner now appears recommending the Android app for a better experience',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 115,
    label: 'Invite code fix + email invites',
    changes: [
      'Fixed a bug that caused "something went wrong" when entering an invite code — invites now work correctly',
      'You can now send an email invite directly from the Add Member sheet — if someone doesn\'t have a WabWay account yet, tap "Send email invite" to generate a code and open your mail app with it pre-filled',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 114,
    label: 'Location sharing improvements',
    changes: [
      'Location sharing now keeps running when you navigate away from the Crew screen — it only stops when you tap the toggle or the "Stop sharing" notification button',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 113,
    label: 'Location sharing notification',
    changes: [
      'The location sharing notification can no longer be accidentally dismissed — it stays until you stop sharing',
      'A "Stop sharing" button now appears directly in the notification so you can stop without opening the app',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 112,
    label: 'Money page scrolling',
    changes: [
      'The spending summary cards on the Money page now scroll away with the receipt list instead of staying stuck at the top',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 111,
    label: 'Import photo fix',
    changes: [
      'Spots saved from the Import screen (Google Maps link, social media captions) now get a photo automatically, just like spots added from the Maps import list',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 110,
    label: 'Web login fix',
    changes: [
      'Fixed a crash that showed a grey screen after logging in on web — the app now loads correctly on wabway.wabble.ca',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 109,
    label: 'Find Me + meetup points',
    changes: [
      'New 🆘 Find Me button in crew chat — sends your location to the crew with a push alert so they can navigate straight to you',
      'Long-press anywhere on the Live Map to set a meetup point — crew get a notification and a Navigate button in chat',
      '"Meet in the middle" button on the Live Map (when 2+ people are sharing) auto-calculates the midpoint between everyone',
      'Crew gets a notification when someone starts sharing their location',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 108,
    label: 'Background location sharing + navigate to crew',
    changes: [
      'Location sharing now keeps running in the background — a notification appears when active so you always know it\'s on',
      'Tap any crew member\'s dot on the Live Map to get directions straight to them',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 107,
    label: 'Mobile web fixes',
    changes: [
      'Opening wabway.wabble.ca on mobile now shows the app icon and a spinner instead of a blank screen while everything loads',
      'The Search keyboard key in place search now reliably shows results on mobile — no more results disappearing when the keyboard closes',
      'Search field now shows "Searching in [destination]" to confirm your trip\'s location is being used for local results',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 106,
    label: 'Smarter spot search',
    changes: [
      'Searches in Add Spot are now biased toward your trip destination — short queries like "GU" return results in Japan when you\'re travelling there',
      'The search field now shows a "Tap 🔍 or press Search" hint so the submit trigger is always visible',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 105,
    label: 'Import & spot search fixes',
    changes: [
      'Fixed garbled characters (Japanese, Korean, and other CJK text) in Google Takeout CSV imports',
      'Import now shows a "Searching…" spinner per spot while looking up locations — no more premature "No location found" messages',
      'Saving a batch shows progress ("Adding 3 of 12…"), saves in parallel, and closes automatically when done',
      'Spots imported from a Maps link with no city now get reverse-geocoded — "Unknown" is no longer stored',
      'Keyboard Search key in Add Spot now triggers the search correctly',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 104,
    label: 'Notification polish + deep linking',
    changes: [
      'Tapping a push notification now takes you directly to the right section — crew message goes to Chat, spot to Spots, receipt to Money, travel item to Travel',
      'Notification preferences are now respected — disabling a category stops those push alerts',
      'New push events: receipt added and travel item added',
      'Notification settings: new Crew Chat toggle, removed the old "coming soon" placeholder',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 103,
    label: 'Push notifications',
    changes: [
      'Push notifications are live — get alerted when crewmates add spots, log receipts, add travel items, or send a crew message',
      'Notification Settings now has real toggles for Crew, Spots, Money, and Travel — turn off any category you don\'t need',
      'Tapping a notification opens WabWay directly to the relevant screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 102,
    label: 'Spot → Plan, crew chat shortcut, and more',
    changes: [
      'Add any spot to your itinerary in one tap — "Add to Plan" appears inside every spot detail; pick the day and an optional time and you\'re done',
      'Crew Chat is now one tap from the Home screen — chat icon in the AppBar so you don\'t have to open More',
      'Saved a hotel in Travel? A prompt offers to copy it to Stays automatically — check-in/out dates pre-filled',
      'Plan screen now shows an offline banner when a sync fails, consistent with all other screens',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 101,
    label: 'Performance fix — background tickers',
    changes: [
      'Fixed jank caused by the map and live location screens running at 60 fps even while you were on a different tab — navigation and scrolling should feel noticeably smoother',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 100,
    label: 'Google Places photos + speed improvements',
    changes: [
      'Spot photos now come from Google Places — sharper and more accurate than the previous Wikipedia images',
      'App startup and screen transitions are faster: text styles initialised once, activity feed uses constant-time lookups, heavy widgets isolated to avoid unnecessary redraws',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 99,
    label: 'Planned cost on itinerary items',
    changes: [
      'Add an estimated cost (amount + currency) to any plan item — shown as a chip on the timeline',
      'Day card footer shows a running total for all costed items; currency auto-groups if you mix currencies',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 98,
    label: 'Clear packed items',
    changes: [
      'Packing list AppBar now shows a ⋮ menu when items are packed',
      '"Clear packed items" bulk-removes all packed items after a confirmation dialog',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 97,
    label: 'Delete plan day',
    changes: [
      'Day card header now shows a ⋮ menu with "Edit day" and "Delete day" options',
      'Deleting a day shows a confirmation dialog and removes the day and all its items permanently',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 96,
    label: 'Map category filter',
    changes: [
      'Map now shows category chips at the top — tap to hide/show spots by type (Restaurant, Hotel, etc.)',
      'Only appears when 2+ categories are present; chip count shows how many spots are in each category',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 95,
    label: 'Packing list reorder',
    changes: [
      'Drag the ≡ handle on any unpacked packing item to rearrange it — order is saved for everyone',
      'Searching hides handles to avoid confusion while filtering',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 94,
    label: 'Spot status quick actions',
    changes: [
      'Spot detail now shows a "Skip" button alongside "Mark as visited" for active spots',
      'Visited/skipped spots show an "Undo" button to revert to confirmed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 93,
    label: 'Receipt date range filter',
    changes: [
      'New date range chip on the receipts list — tap to pick a start and end date and see only those expenses',
      'Works alongside the category filter and search; tap the X on the chip to clear',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 92,
    label: 'Visited spot styling',
    changes: [
      'Visited spots are now visually dimmed with a green checkmark on the photo',
      'Skipped spots are further dimmed with a grey X overlay — easy to spot at a glance',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 91,
    label: 'Travel item countdown',
    changes: [
      'Travel cards now show how many days away the departure/event is ("Tomorrow", "In 3 days")',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 90,
    label: 'Text encoding fix',
    changes: [
      'Fixed garbled text characters that appeared in the plan, docs, accommodations, and travel screens',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 89,
    label: 'Packing list search',
    changes: [
      'Search the packing list by item name — useful when the list gets long',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 88,
    label: 'Packing item assignment',
    changes: [
      'Assign packing items to trip members — tap the menu and choose "Assign to..." to pick who\'s responsible for bringing an item',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 87,
    label: 'Packing item rename',
    changes: [
      'Packing items now have a menu — tap the three-dot icon to rename or delete an item',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 86,
    label: 'Link editing',
    changes: [
      'Saved links can now be edited — tap the menu on any link card to update the title, URL, category, or notes',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 85,
    label: 'Packing "packed by" credit',
    changes: [
      'Packed items now show who marked them as packed — "Packed by Alex" or "Packed by you"',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 84,
    label: 'Stay check-in countdown',
    changes: [
      'Accommodation cards now show how many days until check-in, "Check-in today!", or "Staying now" when you\'re mid-stay',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 83,
    label: 'Tap links in activity feed',
    changes: [
      'Activity feed entries for saved links are now tappable — tap to open the link in your browser',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 82,
    label: 'Packing list grouping',
    changes: [
      'Packed items now move to a "Packed (N)" section at the bottom — still-to-pack items stay at the top',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 81,
    label: 'Receipt search',
    changes: [
      'Search receipts by title, category, or notes — composable with the category filter and sort order',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 80,
    label: 'Internal cleanup',
    changes: [
      'Removed redundant _fmtDate wrappers in service classes — all date formatting now goes through the shared isoDate helper',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 79,
    label: 'Links in global search',
    changes: [
      'Saved links now appear in global search — search by title, domain, URL, or notes; tap to open in browser',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 78,
    label: 'Duplicate receipt',
    changes: [
      'Duplicate any receipt from the detail screen — opens the form pre-filled so you only need to adjust the amount',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 77,
    label: 'Group chat link',
    changes: [
      'Organisers can add a group chat link in Trip Settings — WhatsApp, Telegram, Signal, or any URL; one tap opens the group from the Members screen',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 76,
    label: 'Day attendance',
    changes: [
      'Plan day cards now show who\'s present each day — based on each member\'s arrival and departure dates',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 75,
    label: 'Member trip dates',
    changes: [
      'Set personal arrival and departure dates on the Members screen — the group can see when each person is joining and leaving',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 74,
    label: 'Pinboard realtime',
    changes: [
      'Pinboard now updates live — new notes from other members appear instantly without refreshing',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 73,
    label: 'Receipt CSV export',
    changes: [
      'Export your receipts as a CSV file from the Money tab — useful for expense reports or sharing with an accountant',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 72,
    label: 'Trip pinboard',
    changes: [
      'Post notes the whole group can see — great for check-in codes, meet times, and reminders',
      'Pinned notes appear on the Home screen; manage them from Settings',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 71,
    label: 'UI polish — receipts & spots',
    changes: [
      'Receipt notes now show inline in the receipt list (1 line preview)',
      'Spots with comments show a comment count next to the vote summary',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 70,
    label: 'Plan item comments',
    changes: [
      'Leave notes on any plan item — useful for last-minute updates ("restaurant closed Mondays") the whole group can see',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 69,
    label: 'Mark spots as visited',
    changes: [
      'Spots now have a "Visited" status — tap "Mark as visited" inside any spot to record that you\'ve been there',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 68,
    label: 'Packing list in global search',
    changes: [
      'Search now finds items on your packing list — packed items are labeled "Packed ✓"',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 67,
    label: 'Cover photo on home card',
    changes: [
      'Your trip cover photo now shows as a banner at the top of the home card — set it in Trip Settings',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 66,
    label: 'Trip budget tracking',
    changes: [
      'Set a total trip budget in Trip Settings — home screen shows a live spent vs. budget bar that turns red if you go over',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 65,
    label: 'Tap to mark done from home',
    changes: [
      "Tap any item on today's home card to mark it done — no need to navigate to Plan; update is instant with automatic rollback if offline",
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 64,
    label: 'Packing list',
    changes: [
      'Shared packing checklist for the group — tap to check items off, everyone sees updates in real time',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 63,
    label: 'Emergency info card',
    changes: [
      'New Emergency Info screen under Settings: store insurance, card emergency line, embassy contacts, nearest hospital — tap phone numbers to dial, tap codes to copy',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 62,
    label: 'Offline currency converter',
    changes: [
      'Tap the exchange icon on the Money screen to convert any logged currency to your home currency — uses stored receipt rates, works offline',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 61,
    label: 'Quick expense button',
    changes: [
      'Tap the + button on the home screen to log an expense instantly — no more navigating to Money first',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 60,
    label: 'Copy address & confirmation number',
    changes: [
      'Tap a spot address to copy it — handy for pasting into Maps or a message on the go',
      'Travel item confirmation numbers and addresses now have a copy icon — one tap copies to clipboard',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 59,
    label: "Today's agenda on home",
    changes: [
      "When today is a planned day, the home screen now shows a full Today card with all your items, their times, and live done/total progress — replaces the single-item 'Coming up' card while travelling",
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 58,
    label: 'Code cleanup — date utils, ISO formatting',
    changes: [
      'Consolidated 5 duplicate ISO date-formatting blocks (yyyy-MM-dd) across service files into a single isoDate() helper — internal cleanup only, no visible changes',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 57,
    label: 'Spending by member',
    changes: [
      'New "Spending by member" card on the Receipts tab shows who paid the most and their proportion of total group spending — auto-hides when only one person paid',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 56,
    label: 'WabwayFilterStrip — shared filter chips',
    changes: [
      'Extracted a shared WabwayFilterStrip<T> widget — the Stays, Receipts, and Links filter chip rows are now all powered by the same component',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 55,
    label: 'Settings, offline stays, date cleanup',
    changes: [
      'Settings screen now has working Trip Settings and Invite Members tiles — the old "Coming soon" placeholder is gone',
      'Accommodations screen shows an offline banner when a background sync fails, consistent with all other screens',
      'Eliminated 5 duplicate date-format functions across the codebase — all consolidated into one shared fmtDate helper',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 54,
    label: 'Loading state refactor',
    changes: [
      'Extracted WabwayLoadingScaffold and WabwayLoadingIndicator widgets — 8 screens no longer have copy-pasted loading blocks; consistent spinner across the whole app',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 53,
    label: 'Search stays in global search',
    changes: [
      'Global search now includes your saved accommodations — search by hotel name, city, address, or notes and tap to open the stay detail',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 52,
    label: 'Day completion badge',
    changes: [
      'Plan day headers now show a "2/5" done/total badge when items are checked off — turns green when the whole day is complete',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 51,
    label: 'Check off plan items',
    changes: [
      'Tap the coloured dot on any plan item to mark it done — the title gets a strikethrough and the dot turns into a green checkmark; tap again to uncheck',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 50,
    label: 'WabwaySearchBar widget',
    changes: [
      'Extracted a shared WabwaySearchBar widget that replaces the repeated TextField implementation in Links, Travel, Plan, and Stays screens — same look, less code to maintain',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 49,
    label: 'Travel type filter counts',
    changes: [
      'Travel type filter chips now show counts ("Flight (2)", "Train (3)") and only appear when 2+ types are present in the list — consistent with spots and links',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 48,
    label: 'Spot category counts',
    changes: [
      'Category filter chips on the Spots screen now show counts ("Food (5)", "Activity (3)") — consistent with the Links and Money filter strips',
      'Categories with no spots in the current list are hidden, keeping the strip compact',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 47,
    label: 'Stays search',
    changes: [
      'Search accommodations by name, city, address, or notes — the search bar appears above the status filter on the Stays screen',
      'Search and status filter work together so you can find, for example, all booked stays in Tokyo',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 46,
    label: 'Plan search',
    changes: [
      'Search plan items by title, location, city, or notes — a search bar appears at the top of the Plan screen whenever days are loaded',
      'Matching items are shown in a flat results list with their day context (Day 3 · Tokyo); tapping opens the full item detail as usual',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 45,
    label: 'Receipt date grouping',
    changes: [
      'Receipts are now grouped under date headers (Mon, Jul 7) when sorted by newest or oldest — makes it easy to scan daily spending at a glance',
      'Date headers are skipped when sorted by amount, so the amount-sorted view stays clean',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 44,
    label: 'Code comments pass',
    changes: [
      'Added human-style comments to money_screen, global_search_screen, links_screen, travel_screen, and map_screen explaining non-obvious logic such as the parallel fetch strategy, closure capture pattern, and silent-reload debounce',
      'Fixed missing semicolon on an import in incoming_share_screen that was causing a parse error',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 43,
    label: 'Travel search',
    changes: [
      'Search travel items by title, location, destination, confirmation number, or notes — the search bar appears at the top of the Travel screen',
      'Search and type filter (Flight, Hotel, Train, etc.) work together so you can find, for example, all trains to Osaka',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 42,
    label: 'Receipt sorting',
    changes: [
      'Sort receipts by newest first, oldest first, highest amount, or lowest amount — tap the sort icon next to the filter chips to switch modes',
      'The sort icon turns blue when a non-default sort is active so you always know the list is sorted',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 41,
    label: 'Links search',
    changes: [
      'Search saved links by title, domain, or notes — the search bar now appears at the top of the Links screen whenever links are loaded',
      'Search and category filter work together so you can narrow down to, say, only food links that mention a specific restaurant',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 40,
    label: 'Spending by category',
    changes: [
      'A spending breakdown card now appears at the top of the Receipts tab when your trip has expenses in more than one category — shows each category\'s total and a mini progress bar so you can see where the money went at a glance',
      'The breakdown uses the home-currency equivalent for all amounts, so mixed-currency trips still show a consistent total',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 39,
    label: 'Links filter + map polish',
    changes: [
      'Filter saved links by category — Food & drink, Stay, Activity, Article, Social, and more — with a single tap; shows counts and auto-hides when all links share the same category',
      'Map screen realtime updates no longer flash a loading spinner — changes stream in silently while you browse spots',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 38,
    label: 'Cash withdrawal notes',
    changes: [
      'Cash withdrawal notes now show in the list — useful for recording which ATM you used or any transaction details worth remembering',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 37,
    label: 'Tappable activity feed',
    changes: [
      'Activity events on the home screen are now tappable — tap any spot, document, travel item, receipt, or plan item event to jump straight to the detail screen',
      'A chevron arrow appears on tappable events so you know which ones navigate somewhere',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 36,
    label: 'Receipt filters + travel order',
    changes: [
      'Filter receipts by category — Food, Transport, Stay, Activity, Shopping, or Other — with a single tap; the chip shows how many receipts are in each category',
      'Filter is hidden when all receipts fall into the same category, so it only appears when it helps',
      'Travel items are now sorted by departure date so the list reads like the trip timeline — draft bookings with no date appear at the end',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 35,
    label: 'Spot notes in list',
    changes: [
      'Spot notes now show in the list view — up to 2 lines, so you can see your own reminders at a glance without opening the spot',
      'Notes appear between the city/category line and the vote summary, hidden when empty so the card stays compact',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 34,
    label: 'Multi-currency balance',
    changes: [
      'Home screen balance card now shows debts and credits in every currency separately — no more missing JPY debts when your trip also has CAD expenses',
      'Total spent on the home screen now uses home-currency equivalents so the number is consistent when you mix currencies',
      'Accommodations screen now updates in real-time when a trip-mate adds or edits a stay',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 33,
    label: 'Tappable search results',
    changes: [
      'Search results are now tappable — tap any result to open the full detail screen',
      'Spots, documents, travel items, receipts, and itinerary items all navigate directly',
      'A chevron icon on each card makes it clear every result is tappable',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 32,
    label: 'Spot export + tappable trip hero',
    changes: [
      'Export your visible spots as a CSV — tap the export icon in the Spots screen to share a spreadsheet with name, city, category, status, address, and notes for every spot currently shown',
      'Filters and sort order are respected: the CSV contains exactly what you see on screen',
      'Trip owners can now tap the home screen hero card to open Trip Settings directly — a small edit icon appears as a hint',
      'Non-owners see the card as before: no tap, no icon',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 31,
    label: 'Spot sorting + trip countdown',
    changes: [
      'Sort your spots by "Newest first", "A – Z", or "Most voted" — tap the sort icon in the Spots screen',
      'Must-do votes rank highest when sorting by Most voted, with total vote count as tiebreaker',
      'Trip hero on the Home screen now shows how many days until departure, which day of the trip you\'re on, or how long ago the trip ended',
      'Countdown is hidden automatically when the trip has no start or end date set',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 30,
    label: 'Google Places search',
    changes: [
      'Place search now uses Google Places (via the WabWay server) for much better results — restaurants, shops, and local businesses are found instantly',
      'Search fires when you press Enter or tap the search icon, not on every keystroke — no accidental API charges',
      'Falls back to Photon (OpenStreetMap) automatically when the server is unavailable',
      'Both the Add Spot and Add Plan Item location fields share the same search widget and engine',
      'Google Takeout CSV geocoding also uses Google Places as the first lookup before falling back to Nominatim',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 29,
    label: 'CSV import & share support',
    changes: [
      'Share a CSV from Google Takeout directly to WabWay — goes straight to the import screen',
      'WabWay now appears in the share menu for CSV, XLS, and XLSX files',
      'Picking a CSV in the in-app import picker no longer asks you to pick the file a second time',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 28,
    label: 'Spot country + better Maps import',
    changes: [
      'Spots now have a Country field — auto-filled when using place search or pasting a Maps link',
      'Paste any Google Maps link (short or full) — name, city, and country are looked up automatically',
      'Short links (maps.app.goo.gl) now resolve correctly instead of only extracting coordinates',
      'Sharing a Google Maps link pre-fills the spot form with place name, city, and country',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 27,
    label: 'Plan item improvements',
    changes: [
      'Pick a spot to auto-fill the plan item title, address, city, country, and Google Maps link',
      'Location / Address field now autocompletes as you type — powered by Photon',
      'New Country field on plan items, auto-filled from address search',
      'Spot picker sits above the title so you can pre-fill before editing',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 26,
    label: 'Bug fixes',
    changes: [
      'Exchange rate no longer shows 0.00 — now uses the /latest Frankfurter endpoint which is always available',
      'What\'s new shows as a centred dialog on desktop instead of a cropped bottom sheet',
      '"What\'s new" button added to the desktop sidebar so it\'s reachable without going through More',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 25,
    label: 'Auto-fetch spot thumbnails',
    changes: [
      'Spots added before thumbnails were introduced now get Wikipedia images automatically',
      'Images stream in as they load — no need to re-add spots',
      'Already-found images are saved to the database so they load instantly next time',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 24,
    label: 'Multi-currency receipts',
    changes: [
      'Receipts in foreign currencies now show the home-currency equivalent (e.g. ≈ C\$89.43)',
      'Exchange rate is locked at the time of purchase — balances stay accurate even if rates shift',
      'Optional transaction fee field to capture card surcharges',
      'Set your settlement currency (e.g. CAD) in Trip Settings → Settlement currency',
      'Old receipts backfilled with exchange rate 1 — update them manually if needed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 23,
    label: 'Document thumbnails',
    changes: [
      'Image documents now show a real preview thumbnail in the docs grid and list',
      'Thumbnails are served from Supabase\'s CDN — fast after the first load, no extra uploads',
      'Non-image files (PDFs, etc.) are unchanged',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 22,
    label: 'Caption extraction & paste fallback',
    changes: [
      'Instagram and TikTok captions are now fetched server-side, fixing CORS errors on web builds',
      'Audio transcription automatically pulls the post caption too and combines place candidates from both',
      'Paste fallback: copy-paste a caption manually if auto-fetch isn\'t available — tap "Find places" to scan it',
      'Place extraction is smarter — fewer false positives from sentence-starting words',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 21,
    label: 'Unified import & share screen',
    changes: [
      'Import and share intake are now one screen — same flow whether you\'re sharing from another app or importing manually',
      'Import mode lets you pick a file, take a photo, or paste a URL before continuing',
      'Plan item destination fully wired — pick day and item type in one step',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 20,
    label: 'Audio transcription for social shares',
    changes: [
      'Share a TikTok or Instagram video to WabWay and it extracts place names from the audio narration',
      'Transcription runs on-device via whisper.cpp (requires the WabWay server on your phone)',
      'Found places are geocoded and dropped straight into the spot picker',
      'Banner is hidden automatically when the server isn\'t configured',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 19,
    label: 'Shared photo albums',
    changes: [
      'New Photos section — drop links to everyone\'s photo albums in one place',
      'Supports Google Photos, iCloud, Dropbox, and any album link',
      'Step-by-step guide for setting up a collaborative Google Photos album the whole group can upload to',
      'Auto-detects the album service from the URL',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 18,
    label: 'Google Maps import & spot photos',
    changes: [
      'Import entire pin lists from Google Maps via share sheet',
      'Auto-fetches Wikipedia photos for imported spots',
      'Google Takeout CSV support for custom named lists',
      'Live geocoding — list appears instantly, locations fill in as they resolve',
      'WebView scraper tries to read JS-rendered Maps list pages directly',
      'Spots that can\'t be located are flagged "No location found" instead of dropped',
      'Spot list card and detail header now show place photos when available',
      'Duplicates in CSV exports are automatically removed',
      'Notes from your Maps saves are preserved on the spot',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 17,
    label: 'Two-pass OCR & AI itinerary parsing',
    changes: [
      'Two-pass OCR for low-contrast or small-text documents',
      'Gemini AI fallback for multi-column and complex booking formats',
      'Handles 2-column Gmail booking email layout',
      'Parse mode shown in banner: "AI" vs "OCR"',
      'PDF text-layer extraction before falling back to image OCR',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 16,
    label: 'Share intake & individual place import',
    changes: [
      'Share any Google Maps place link directly to WabWay',
      'Resolves short maps.app.goo.gl links via redirect tracking',
      'Nominatim geocoding when Maps URL has no coordinates',
      'My Maps (custom maps) imported via KML export',
      'New app icon and adaptive icon for Android',
    ],
  ),
  _Release(
    version: '1.0.0',
    build: 12,
    label: 'Stability & build fixes',
    changes: [
      'Fixed R8 minification crash on release builds',
      'Fixed Play Core missing classes at runtime',
      'Disabled shrink resources to prevent asset stripping',
    ],
  ),
];

// ─── Model ────────────────────────────────────────────────────────────────────

class _Release {
  const _Release({
    required this.version,
    required this.build,
    required this.label,
    required this.changes,
  });

  final String       version;
  final int          build;
  final String       label;
  final List<String> changes;

  String get displayVersion => '$version ($build)';
}

// ─── Logic ───────────────────────────────────────────────────────────────────

abstract final class ChangelogService {
  static const _prefKey = 'last_seen_build';

  /// Returns true and updates the stored build if the app was upgraded.
  static Future<bool> checkIfUpgraded() async {
    final info  = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final last  = prefs.getInt(_prefKey) ?? 0;
    if (build > last) {
      await prefs.setInt(_prefKey, build);
      return true;
    }
    return false;
  }

  /// Show the changelog. Uses a centered dialog on wide screens, bottom sheet on mobile.
  static Future<void> show(BuildContext context, {bool forceShow = false}) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => const _ChangelogDialog(),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangelogSheet(),
    );
  }

  /// Call from the shell's initState — shows once after an upgrade.
  static Future<void> maybeShowOnLaunch(BuildContext context) async {
    final upgraded = await checkIfUpgraded();
    if (upgraded && context.mounted) {
      // Small delay so the shell finishes building first
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (context.mounted) show(context);
    }
  }
}

// ─── Shared content ───────────────────────────────────────────────────────────

Widget _changelogHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace2),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: kColorPrimarySoft,
            borderRadius: kRadiusSm,
          ),
          child: const Icon(Icons.new_releases_rounded,
              size: 18, color: kColorPrimary),
        ),
        const SizedBox(width: kSpace3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("What's new", style: kStyleBodyBold),
            Text('Recent updates to WabWay',
                style: kStyleCaption.copyWith(color: kColorInkSoft)),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

Widget _changelogList(ScrollController? scroll) {
  final releases = _kChangelog.take(20).toList();
  return ListView.separated(
    controller: scroll,
    padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace6),
    itemCount: releases.length,
    separatorBuilder: (_, __) => const Padding(
      padding: EdgeInsets.symmetric(vertical: kSpace4),
      child: Divider(height: 1),
    ),
    itemBuilder: (_, i) => _ReleaseBlock(release: releases[i], isLatest: i == 0),
  );
}

// ─── Mobile bottom sheet ──────────────────────────────────────────────────────

class _ChangelogSheet extends StatelessWidget {
  const _ChangelogSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: kColorCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: kSpace3),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kColorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _changelogHeader(context),
            const Divider(height: 1),
            Expanded(child: _changelogList(scroll)),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop dialog ───────────────────────────────────────────────────────────

class _ChangelogDialog extends StatelessWidget {
  const _ChangelogDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kColorCream,
      shape: RoundedRectangleBorder(borderRadius: kRadiusLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _changelogHeader(context),
            const Divider(height: 1),
            Flexible(child: _changelogList(null)),
          ],
        ),
      ),
    );
  }
}

class _ReleaseBlock extends StatelessWidget {
  const _ReleaseBlock({required this.release, required this.isLatest});
  final _Release release;
  final bool     isLatest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(release.displayVersion,
                style: kStyleOverline.copyWith(color: kColorInkSoft)),
            if (isLatest) ...[
              const SizedBox(width: kSpace2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace2, vertical: 2),
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Latest',
                    style: kStyleOverline.copyWith(
                        color: kColorTextOnPrimary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        const SizedBox(height: kSpace1),
        Text(release.label, style: kStyleBodySemibold),
        const SizedBox(height: kSpace3),
        ...release.changes.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: kColorPrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Text(c,
                      style: kStyleBodyMedium.copyWith(
                          color: kColorInk, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
