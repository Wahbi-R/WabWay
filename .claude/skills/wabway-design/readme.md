# Wabway Design System

Wabway is a private, collaborative trip-planning app for small friend groups. One shared workspace per trip holds the places everyone wants to visit, the links people paste in from Instagram/TikTok/Google Maps, the PDFs and receipts that pile up before a trip, shared expenses, ATM cash withdrawals, and the day-by-day itinerary — so a group doesn't end up with the plan scattered across five group chats and a Google Doc.

It's a personal/side project (currently a planning README, pre-implementation) built to gain full-stack experience with Flutter + Supabase. The first real trip it's being built for is a Japan trip with friends, but every screen is written to generalize to any small group trip.

**Target platforms:** Android app and a desktop web app, from one Flutter codebase. Every screen in this system is designed twice: a stacked single-column mobile layout, and a sidebar + list/detail desktop layout.

## Sources

This system was built from:

- **GitHub — [Wahbi-R/WabWay](https://github.com/Wahbi-R/WabWay)** — at the time of writing this repo contains a single detailed planning `README.md` (product concept, data model, navigation, screen list, and a suggested color palette). There is no committed app code, Figma file, or visual asset yet — this design system is the first visual expression of that spec.
- The brand brief pasted alongside the repo (color palette, style adjectives, mobile/desktop navigation structure, the reusable-component list).

**If you have access to the repo above, go read it.** It contains the full feature spec (native Android share-intent flows, the receipt-splitting math, cash/ATM tracking rules, the complete data model) in far more depth than this design system restates. Anything here that looks underspecified — copy for a screen this system didn't build, an edge case, a data field — is probably answered there. As the app gets actually built in Flutter, treat that repo (and whatever Figma/code follows it) as the ground truth this design system should be kept in sync with.

## What's in this project

- `tokens/` — color, type, spacing, radius, shadow, and motion CSS custom properties. `styles.css` at the project root is the single entry point (`@import`s only).
- `components/` — reusable React UI primitives, grouped by concern. See the index at the bottom of this file.
- `ui_kits/wabway-mobile/` and `ui_kits/wabway-desktop/` — click-through recreations of the core app screens.
- `guidelines/` — foundation specimen cards (also browsable in the Design System tab).
- `assets/` — wordmark, app icon mark, and the icon set.
- `SKILL.md` — portable skill manifest so this system can be dropped into Claude Code or another agent environment.

## Content fundamentals

Wabway's only existing copy is its own planning README, so the voice here is extrapolated carefully from it rather than copied wholesale — treat it as a strong starting direction, not gospel.

**Voice:** plain, direct, a little dry-friendly. The source README describes the app as "for reference, mostly vibe coded" and pitches it as "a private trip-planning app for small friend groups" in one unadorned sentence — no hype, no exclamation points, no startup-speak. Copy should read like a competent friend explaining something quickly, not like marketing.

**Person:** second person for instructions and the user's own state ("You owe Alex ¥3,200"), third person/plain noun for other members ("Alex paid their own share"). Never refer to "the user" in UI copy.

**Casing:** sentence case everywhere — buttons, headings, nav labels, empty states. Never title case, never all-caps except a single optional overline label (e.g. a small "TRIP" eyebrow above a hero name) used sparingly.

**Numbers & money:** always show the currency symbol attached to the number with no space (¥8,400, not ¥ 8,400 or 8400 JPY). Settlement language is literal and people-first: "You owe Alex: ¥3,200" / "You are owed: Josh ¥5,000". Never "balance: -3200" — always phrase the direction in words.

**Buttons & actions:** short verb phrases, sentence case, no punctuation. "Add a spot", "Invite friends", "Settle up", "Save", "Add receipt" — never "Submit", never "Click here".

**Tone in empty/loading/error states:** calm and useful, not cute. Tell the person what's missing and what to do about it in one line each ("No spots yet" / "Add the first place worth visiting"), rather than a joke or an illustration-driven gag. No filler "Oops!" exclamations on errors — name what happened and offer the next step ("Couldn't load this trip" / "Check your connection and try again").

**Emoji:** not used in product chrome (buttons, nav, labels, system copy). The source material's only non-text symbols are currency marks (¥) and plain punctuation. Avoid emoji as icons or decoration; use the icon set instead.

**Structural habit:** the spec README leans constantly on simple arrow-flow diagrams to explain a process (`Instagram → Share → Wabway → Add to trip as a spot or link`). That same instinct — show the steps, don't narrate them — should carry into onboarding and incoming-share UI copy: short labeled steps over paragraphs.

## Visual foundations

**Color:** warm and travel-toned on purpose — explicitly *not* the blue/indigo SaaS default. Background is a warm cream (`#F8F3EA`), cards sit on an even warmer off-white paper (`#FFFDF8`) so surfaces lift softly off the page without a hard white/gray jump. Primary is a terracotta/clay (`#C96F4A`) — used for primary buttons, active nav states, links, and the brand mark. Secondary is a muted sage green (`#7D9A75`) — used sparingly for secondary affordances and a few category accents (never competes with primary for attention). Accent is a muted gold (`#D6A84F`) — small highlight moments only: an active vote, a star/favorite, a badge. Semantic success/warning/danger are likewise warm-shifted (mossy green, ochre, brick red) rather than stock RGB green/amber/red, so they sit in the same family as everything else. Every hover/active/soft-tint shade is derived from these source hexes with `color-mix()` in OKLCH rather than hand-picked, so the whole system stays harmonious if a base color ever shifts.

**Type:** [Plus Jakarta Sans](https://fonts.google.com/specimen/Plus+Jakarta+Sans) for all UI text — a geometric sans with warm, slightly rounded terminals, friendlier than Inter/Roboto without tipping into a novelty rounded font. [Lora](https://fonts.google.com/specimen/Lora), a warm low-contrast serif, is reserved for editorial/display moments — a trip name on the Trip Home hero, a big pull-quote, an empty-state headline — the equivalent of a stamp in a travel journal next to otherwise-clean UI type. [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) is used narrowly for things that are literally codes or ledger figures: invite codes, confirmation numbers, and amount columns in dense tables. *(These three are Google Fonts substitutions — see the Caveats note at the end of this file.)*

**Spacing & touch targets:** 4px base scale. Interactive targets are never smaller than 44px tall (most primary actions are 52px) — the brief explicitly calls for one-handed, tired-at-the-end-of-a-travel-day usability.

**Backgrounds:** flat warm cream, no gradients, no full-bleed hero photography in the product chrome itself (trip cover photos are the one place a real photo fills a card — everything else is flat color + type + icon). No background patterns or textures.

**Animation:** quick and quiet — 120–320ms, ease-out on entrances (`cubic-bezier(0.16,1,0.3,1)`), standard ease-in-out on toggles/transitions. No bounce, no elastic overshoot, no looping decorative motion. This is a tool people glance at mid-trip, not a showcase.

**Hover states:** primary/secondary/accent solid surfaces darken slightly (`color-mix` toward black, ~12–15%); soft/tinted surfaces (badges, chip backgrounds) stay flat and instead the border firms up. Ghost/ text buttons gain a faint tinted background on hover, never just a color change with nothing else.

**Press / active states:** a touch deeper darken than hover (~22–24% toward black) plus a 1px scale-down feel via the deeper shadow collapsing to `--shadow-xs` — no transform/scale jump, keeps things calm.

**Borders:** a single hairline neutral border color (`#E6DCCF`, derived as `--color-border`) outlines cards, inputs, and dividers at 1px. A slightly stronger derived border is used only for emphasis (an input in an error state, a selected card).

**Shadows:** soft and warm-tinted (the shadow color is the ink/brown text color at low opacity, never pure black) with generous blur and minimal spread — paper resting on paper, not UI floating in space. Three steps: `--shadow-sm` for resting cards, `--shadow-md` for raised/hoverable cards and dropdowns, `--shadow-lg` for modals/sheets.

**Corner radii:** soft and consistently rounded, scaling with the size of the element — 10px on inputs/small chips, 14px on buttons, 20px on cards, 28px on large sheets/modals, full pill on tags/votes/badges. Never sharp corners.

**Transparency & blur:** used in exactly two places — a modal/sheet scrim (`--color-overlay`, ink at ~55% opacity) and nothing else. No frosted-glass/backdrop-blur chrome; it reads as cold/tech rather than warm/travel.

**Layout rules:** mobile is strictly single-column, stacked cards, with a fixed bottom nav (5 items: Spots, Plan, Money, Docs, More) and a floating-feeling primary action where relevant. Desktop is a fixed-width left sidebar (10 items: Home, Spots, Links, Map, Plan, Travel, Money, Documents, Members, Settings) plus a flexible content area that opens into two-column list/detail patterns for anything list-like (receipts, documents, cash history).

**Imagery:** no production photography exists yet. Where a photo placeholder is needed (a spot's cover photo, a trip cover), use a warm-toned placeholder treatment (soft gradient-free tint block, not a gray box) so unfilled imagery doesn't read as cold or broken — see `components/core/Card` photo-slot pattern.

## Iconography

No icon font, sprite sheet, or SVG set exists in the source repo. The brief asks for "simple line icons" generally and doesn't name a system.

**Substitution:** [Lucide](https://lucide.dev) icons, loaded from CDN (`unpkg.com/lucide-static` or the `lucide-react` package), at the default 1.75–2px stroke weight to match the warm-but-clean, slightly-rounded-cap line style described in the brief. Lucide was chosen over Heroicons/Feather for its rounded line caps (matching the soft-radii visual language) and because it covers every travel/finance/document glyph this product needs (map pin, plane, receipt, wallet, banknote, file-text, vote/check, users). *(Flagged substitution — see Caveats.)*

**Usage:** icons are always single-color, inheriting `currentColor` so they pick up text-primary, text-secondary, primary, or semantic colors depending on context — never a separate icon-specific color. Default size 20px inline with body text, 24px in nav and section headers, 16px in dense table rows and chips. Icons sit to the *left* of a text label with `--space-2` (8px) gap, never on the right except a trailing chevron for disclosure/navigation rows.

**Emoji:** none in product chrome. Unicode currency symbols (¥, $) are used as plain text, not as icon-style glyphs.

**Copied assets:** see `assets/` — a wordmark lockup and a standalone mark, both built from the type system (no source logo file existed to copy), plus the Lucide icons actually used across the components/UI kits, copied locally as SVGs.

## Index

```text
styles.css                   single entry point (@imports only)
tokens/                       colors, typography, spacing, radius, shadows, motion, fonts
assets/icons/                 62 Lucide SVGs (single-color, mask-tinted via the Icon component)
guidelines/                   24 foundation specimen cards (Colors, Type, Spacing, Brand groups)

components/
  core/        Button, IconButton, Badge, Tag, Avatar, Card, PhotoSlot, Tabs, Tooltip, Icon
  forms/       Input, Textarea, Select, Checkbox, Radio, Switch
  feedback/    Toast, Dialog, EmptyState, LoadingState, ErrorState, Banner
  navigation/  BottomNav (mobile), Sidebar + TopBar (desktop)
  board/       TripCard, SpotCard, LinkPreviewCard, VoteChip/VoteChipGroup, CommentThread, MemberAvatarRow
  itinerary/   ItineraryDayCard, TravelItemCard
  files/       DocumentTile, IncomingShareCard
  money/       ReceiptCard, SplitMemberRow, BalanceSummaryCard, CashWithdrawalCard, CashDistributionRow

ui_kits/
  wabway-mobile/    Android app — Spots, Plan, Money, Documents, More (interactive click-through)
  wabway-desktop/   Desktop web app — sidebar nav, Home/Spots/Plan/Money/Documents/Members

SKILL.md                      portable skill manifest (Claude Code-compatible)
```

`AppShell` / `ResponsiveScaffold` from the original widget list aren't standalone components here — they're realized as the page-layout patterns themselves (bottom-nav shell on mobile, sidebar shell on desktop) inside each UI kit's app file.

## Caveats & where to help next

- **No code or visuals exist yet for Wabway** — the GitHub repo is a planning README only. Every visual decision here (exact spacing, icon choice, the serif/sans pairing, card shadows) is this system's best interpretation of the brief, not a recreation of something that already shipped. Treat it as v1, not gospel.
- **Fonts are a flagged substitution** — Plus Jakarta Sans / Lora / IBM Plex Mono, loaded via Google Fonts. If you have a preferred type direction, swap `tokens/fonts.css`.
- **Icons are a flagged substitution** — Lucide, since no icon set was specified. If the real Flutter app ends up using a different icon package (e.g. Material Symbols, which would be a natural default for a Flutter/Android-first app), swap `assets/icons/` and update the `Icon` component usages.
- **Desktop UI kit leaves 4 of 10 sidebar sections as placeholders** (Links, Map, Travel, Settings) — Home, Spots, Plan, Money, Documents, and Members are fully designed; the rest weren't speced in enough detail yet to design with confidence rather than invent.
- **No real photography, trip cover images, or a hand-drawn logo exist** — covers and spot photos use the warm `PhotoSlot` placeholder throughout.

**Please weigh in:** does the warm terracotta/sage/gold direction feel right for this group of friends, or too "boutique hotel"? Is Android (Material-adjacent) chrome the right frame, or should the mobile kit lean more iOS-native since friend groups mix platforms? And — most importantly — once any real screens, a logo, or a Figma file exist for Wabway, attach them and this system should be rebuilt against that ground truth rather than the planning doc alone.

