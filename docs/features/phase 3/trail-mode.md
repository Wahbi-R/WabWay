# Trail mode — find the crew with no signal (build 447)

Android only. Not yet tested on real phones — expect range and wake-up timing to need tuning.

**Where:** Crew app bar (hiking icon), More → Explore → Trail. Notification taps (push with
`screen: trail`, or the native wake-up notification) open it via `TrailMode.openRequests` → AppShell.

## How it works

- `TrailService` (foreground service, types `location|connectedDevice`):
  - GPS from `LocationManager` (GPS provider works with no signal; network provider used too when available).
  - Bluetooth LE: scans for WabWay beacons (`SCAN_MODE_BALANCED`) and advertises
    (`LOW_LATENCY`, `TX_POWER_HIGH`, non-connectable). Every 3 s it switches packet: its own
    position every other time, otherwise one crew member it heard (relay, fixes < 40 min old).
  - Keeps the freshest fix per member; direct hearings also record RSSI.
  - State saved to `TrailStore` (SharedPreferences) so the screen and the wake receiver work
    with the app closed and with no signal. Auto-stops after 6 h; Stop action in the notification.
- `TrailBeacon` — 22 bytes of manufacturer data (company 0xFFFF):
  `'W' 'W' 1` · 3-byte trip tag (HMAC of a 10-min slot, rotates so strangers can't follow a phone)
  · one AES-128 block keyed from the trip id: subject index, flags, lat/lng ×1e7, accuracy,
  fix age, sender index, 3 random bytes. Members are numbered by sorting user ids, so every
  phone agrees. Legacy advert size: 22 + 4 + 3 flags = 29 ≤ 31 bytes.
- `TrailWake` / `TrailWakeReceiver` — "Let the crew wake me" (on by default; since build 448 every phone saves the crew list at app start via `TrailMode.autoConfigure`, and Crew asks once for the Bluetooth permission): a PendingIntent
  BLE scan with a hardware filter on the `WW1` prefix, `SCAN_MODE_LOW_POWER`. On a crew beacon:
  start `TrailService` + a heads-up "Trail mode turned on" notification. If Android blocks a
  background start (battery optimisation) or you stopped Trail mode yourself in the last 2 h:
  "X is nearby with Trail mode on — tap to join" (at most every 30 min). Re-armed on boot,
  app update and app start (`TrailMode.init` → `refreshWake`).
- `TrailChannel` — method channel `ca.wabble.wabway/trail`, events `…/trail_events` (state JSON)
  and `…/compass` (rotation-vector heading).

## What each phone needs (the screen's checklist)

| Needed for | Setting |
|---|---|
| Running at all | Nearby devices (Bluetooth scan/advertise/connect) + location permission, Bluetooth on, GPS on |
| Turning on by itself | Location **Allow all the time**, Battery **Unrestricted**; on Samsung also Settings → Battery → Background usage limits → **Never sleeping apps** |
| Hearing about it | Notifications |

## Expectations / limits

- Range between phones roughly 50–100 m in the open, less in forest or with phones in packs.
  Relaying stretches a spread-out group.
- Waking up depends on the background scan, which Android runs in low-power bursts — it may take
  from seconds to a minute or two after someone is in range.
- Android needs location services ON for Bluetooth scans to return anything.

## Ideas not done

- UWB precise distance + direction between Galaxy S Ultra/Plus phones for the last few metres.
- Barometer floor difference for malls.
- Showing positions on the offline map tiles.
