# SOS Button Redesign + High-Priority Alert (Build 118)

## Summary

The "Find Me" SOS button was previously a small 40×40 circle icon tucked in the chat input row alongside the location-ping button. Users could easily miss it or accidentally tap it. This build makes it a full-width, always-visible red button and wires it to a high-priority push notification that bypasses silent mode on both Android and iOS.

## Changes

### `lib/screens/crew_screen.dart`

- **`_sendFindMe()`** — added a confirmation dialog ("Alert your crew?") before sending. Users must tap "Send SOS" to proceed. This prevents accidental triggers.
- **`_InputBar`** restructured from a single row into two rows:
  - **Top row**: full-width `FilledButton` (44 dp tall, `kColorDanger` red) labelled "SOS · Find Me" with `Icons.sos_rounded`. Shows a spinner + "Alerting crew…" while the request is in-flight; disabled during that window.
  - **Bottom row**: Location-ping icon button + message text field + send button (same as before, minus the old small SOS circle).

### `lib/core/notifications/push_notifier.dart`

- Added `highPriority = false` named parameter.
- When `true`, passes `high_priority: true` in the Edge Function body.
- The SOS `pushNotify()` call in `_sendFindMe()` passes `highPriority: true`.

### `supabase/functions/send-notification/index.ts`

- `sendFcm()` receives a new `highPriority` boolean.
- When `true`, merges an `apns` block into the FCM message:
  ```json
  {
    "apns": {
      "headers": { "apns-priority": "10", "apns-push-type": "alert" },
      "payload": { "aps": { "sound": "default", "content-available": 1 } }
    }
  }
  ```
- Android was already `android: { priority: "high" }` for all messages.

## Notification priority

| Platform | Before | After (SOS) |
|----------|--------|-------------|
| Android  | `high` (all messages) | `high` (unchanged) |
| iOS      | default | `apns-priority: 10` + `content-available` |

Non-SOS notifications are unaffected.
