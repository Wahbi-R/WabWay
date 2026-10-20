# AI Access (MCP server)

**Build:** 419  
**Area:** More → Account → AI access (mobile), Settings → Account → AI access (desktop); wabway-server `/mcp`

## What it does

Lets Claude, ChatGPT and any other [Model Context Protocol](https://modelcontextprotocol.io)
client read your WabWay trips directly — bookings with confirmation numbers,
the day-by-day plan, saved spots and documents (PDF text and photos) — so you
never have to screenshot a booking to ask an AI about it. Read-only.

## User-facing changes

- **More → AI access** — explains the feature, lists your active tokens
  (name, `wbw_1234abcd…` prefix, created, last used) and lets you revoke them.
- **Create access token** — name prompt (defaults to "Claude"), then a one-time
  sheet showing the token with copy buttons and ready-made setup for:
  - Claude (web / desktop / phone): Settings → Connectors → Add custom connector,
    URL `https://audio.wabble.ca/mcp?token=wbw_…`
  - ChatGPT: Developer mode connector, same URL, no authentication
  - Claude Code: `claude mcp add --transport http wabway https://audio.wabble.ca/mcp --header "Authorization: Bearer wbw_…"`

## Implementation

| Layer | Change |
|---|---|
| Supabase | Migration `048_ai_access_tokens.sql` — `ai_access_tokens` (`token_hash` SHA-256, `token_prefix`, `last_used_at`, `revoked_at`). Owner can SELECT safe columns and UPDATE only `revoked_at`; no INSERT grant. `create_ai_access_token(p_name)` SECURITY DEFINER RPC generates `wbw_` + 64 hex (pgcrypto), stores the hash, returns the plaintext once; max 10 active per user |
| `lib/data/ai_access_data.dart` | `AiAccessToken` model |
| `lib/core/supabase/ai_access_service.dart` | `load`, `create`, `revoke`, `mcpUrl` (from `AUDIO_SERVER_URL`) |
| `lib/screens/ai_access_screen.dart` | Screen (`AsyncScreenMixin`), token rows, one-time `_NewTokenSheet` via `showWabwayAutoSheet` |
| `lib/screens/more_screen.dart` | "AI access" row in Account |
| wabway-server `wabway_mcp.py` | `POST /mcp` (see below) |

### Server (`wabway-server/wabway_mcp.py`)

- **Transport:** MCP Streamable HTTP, stateless, JSON responses (no SSE). Protocol
  versions 2024-11-05 → 2025-11-25. Written by hand because the `mcp` SDK needs
  pydantic 2, which doesn't build on Termux. `GET`/`DELETE /mcp` → 405.
- **Auth:** `Authorization: Bearer wbw_…` or `?token=wbw_…` (claude.ai/ChatGPT
  custom connectors can't send headers without OAuth). Hash looked up with the
  WabWay service role key, cached 60 s (so revocation applies within a minute);
  `last_used_at` written at most every 10 min. A logging filter redacts tokens
  from the uvicorn access log, which `/logs` serves.
- **Scoping:** the service key bypasses RLS, so every query is filtered by the
  owner's trip ids (`trip_members`), and `get_document` re-checks the document's
  trip. Covered by the test suite (a member of trip A can't see trip B's trips,
  bookings, documents or search hits).
- **Tools (all `readOnlyHint`):** `list_trips`, `get_trip_overview` (members +
  arrival/departure, city per day, emergency info), `get_bookings` (travel +
  stays with attached docs), `get_itinerary` (optional `date`), `get_spots`,
  `list_documents` (with what each is attached to), `get_document` (15-min
  signed URL + PDF text via `pypdf`, or the image inline up to 4 MB),
  `search` (accent-insensitive across travel, stays, plan items, docs, spots).
  `trip` arguments accept a name, destination or id and default to the
  current/next trip.

## Setup on the phone

1. `.env`: `WABWAY_SUPABASE_URL=https://vkrjwywagasubeoxeune.supabase.co` and
   `WABWAY_SUPABASE_SERVICE_ROLE_KEY=…` (Supabase → WabWay → Settings → API keys).
2. `pip install pypdf` (optional — without it PDFs return only the download link).
3. Merge the server branch to `master`; `watch.sh` pulls and restarts.

## Notes / next steps

- OAuth (so claude.ai connectors don't need the token in the URL) would need
  Supabase Auth's OAuth 2.1 server + discovery metadata on wabway-server.
- The server lives on the phone behind the tunnel, so AI access only works
  while it's running. Moving `/mcp` to a Supabase Edge Function would make it
  always-on.
- Possible future tools: receipts / balances, packing list, crew chat.
