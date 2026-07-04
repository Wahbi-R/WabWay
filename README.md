# Wabway

For reference, mostly vibe coded.

A private collaborative trip-planning app for small friend groups.

Wabway is designed for groups who want one shared place to organize travel ideas, links, maps, documents, receipts, cash withdrawals, and itinerary plans. The first use case is a Japan trip with friends, but the app is intended to work for any small group trip.

## Project Goal

The goal of this project is to build a private Android and web app where friends can:

* Join a shared trip workspace.
* Add places they want to visit.
* Paste links from Google Maps, Instagram, TikTok, YouTube, blogs, restaurants, hotel websites, and other sources.
* Share links and files directly into the app from Android’s native share menu.
* Vote and comment on trip ideas.
* Store trip documents such as hotel PDFs, flight confirmations, tickets, receipts, reservations, and forms.
* Track shared expenses.
* Split receipts between selected trip members.
* Track ATM cash withdrawals and cash handed out to friends.
* See who owes who.
* Build a day-by-day itinerary.

This app is being built as a side project to gain experience with full-stack app development, Flutter, responsive UI, Supabase, authentication, database design, file storage, native Android sharing, and collaborative app features.

## Target Platforms

The app is planned for:

* Android app
* Web app for PC browsers

The project will be built with a shared codebase using Flutter.

## Tech Stack

### Frontend

* Flutter
* Dart
* Responsive layouts for mobile and desktop web

### Backend

* Supabase

  * Authentication
  * Postgres database
  * Row Level Security
  * File storage
  * Realtime updates, if needed

### Hosting

* Cloudflare Pages, GitHub Pages, or another free static host for the Flutter web build

### Design

* Figma, Claude Design, or another AI-assisted design tool
* Final implementation will be done manually in Flutter using reusable widgets and responsive layouts

## Core App Concept

Each trip is a private workspace.

A user creates a trip, then invites friends using a link or invite code. Once friends join, everyone can collaborate inside the same trip.

Example:

```text
Create trip
↓
Generate invite code/link
↓
Friends join
↓
Everyone can add spots, links, receipts, documents, comments, and itinerary items
```

## App Name

The app is called **Wabway**.

Possible tagline:

```text
Plan the trip together.
```

Alternative tagline:

```text
One shared place for the whole trip.
```

Longer description:

```text
Wabway helps small groups collect places, links, documents, receipts, cash withdrawals, and itinerary plans in one private trip workspace.
```

## Main Sections

The app will have these main sections:

```text
Wabway
├── Home
├── Spots
├── Links
├── Plan
├── Travel
├── Money
├── Documents
├── Members
└── Settings
```

On mobile, the app may use simplified bottom navigation:

```text
Spots | Plan | Money | Docs | More
```

Where:

```text
Plan = Itinerary, flights, hotels, trains, tickets
Money = Receipts, cash withdrawals, balances, settle up
Docs = PDFs, screenshots, forms, confirmations
More = Members, settings, invite link
```

On desktop, the app may use a sidebar:

```text
Home
Spots
Links
Plan
Travel
Money
Documents
Members
Settings
```

## Main Features

## 1. Trip Membership

Users should be able to create or join trips.

### Features

* Create a trip
* Generate invite link or invite code
* Join trip using invite code/link
* View trip members
* Remove members, if owner
* Assign simple roles

### Roles

```text
Owner
- Can edit trip settings
- Can invite/remove members
- Can edit/delete most trip data

Editor
- Can add and edit spots, comments, expenses, documents, and itinerary items

Viewer
- Can only view trip data
```

For the first version, all friends can simply be editors.

## 2. Native Share Support

Wabway should support receiving shared content from other apps.

Users should be able to share links, text, images, and files directly into Wabway from apps like:

* Instagram
* TikTok
* Google Maps
* Chrome
* YouTube
* Gmail
* Files
* Airline apps
* Hotel booking apps
* PDF viewers

### Example: Instagram Link

A user sees an Instagram reel about a restaurant.

```text
Instagram
↓
Share
↓
Wabway
↓
Add to trip as a spot or link
```

Wabway should open an incoming share screen:

```text
Incoming Share

Detected:
Instagram link

Add to:
- Spot / place idea
- General link
- Itinerary note

Trip:
Japan November

Title:
Instagram reel

City:
Tokyo

Category:
Food

Notes:
Looks like a ramen spot near Shinjuku.

Save
```

### Example: Google Maps Link

A user shares a Google Maps restaurant or attraction.

```text
Google Maps
↓
Share
↓
Wabway
↓
Add as saved spot
```

The app should suggest saving it as a Spot.

### Example: Flight PDF

A user shares a flight confirmation PDF from Gmail, Files, or an airline app.

```text
Gmail / Files / Airline app
↓
Share PDF
↓
Wabway
↓
Add as flight document
```

Wabway should open a document intake screen:

```text
Incoming Document

Detected:
PDF file

Add to:
- Flights
- Hotel
- Train
- Ticket
- Receipt
- Other

Trip:
Japan November

Title:
Air Canada flight confirmation

Attach to:
- New flight item
- Existing itinerary item
- Existing document folder
- Just save to Documents

Date:
Nov 8

Notes:
Outbound flight to Tokyo.

Save
```

### Example: Receipt Photo

A user shares a receipt photo.

```text
Camera / Gallery / Files
↓
Share
↓
Wabway
↓
Create new receipt
```

The app should suggest creating a new expense.

### Supported Shared Content Types

Version 1 should support:

```text
text/plain
- Links
- Notes
- Shared text

image/*
- Receipt photos
- Screenshots
- Travel images

application/pdf
- Flight PDFs
- Hotel PDFs
- Train tickets
- Reservation confirmations
- Forms
- Receipts
```

### Incoming Share Flow

```text
Incoming share detected
↓
Choose trip
↓
App detects content type
↓
Suggest destination
↓
User edits title/category/notes
↓
Save
```

### Suggested Routing

| Shared item             | Suggested destination        |
| ----------------------- | ---------------------------- |
| Google Maps link        | Spot                         |
| Instagram link          | Link or Spot                 |
| TikTok link             | Link or Spot                 |
| YouTube link            | Link                         |
| Restaurant website      | Spot                         |
| Travel blog             | Link                         |
| PDF flight confirmation | Travel → Flights / Documents |
| Hotel PDF               | Travel → Hotels / Documents  |
| Receipt photo           | Money → Receipts             |
| Train ticket PDF        | Travel → Trains / Documents  |
| Random screenshot       | Documents                    |
| Reservation email PDF   | Travel / Documents           |

## 3. Spots and Link Board

The Spots section is the main place for collecting ideas.

Users can add:

* Google Maps places
* Restaurants
* Cafes
* Attractions
* Shops
* Instagram links
* TikTok links
* YouTube videos
* Blog posts
* Hotel/booking links
* Random travel ideas

### Spot Card Fields

```text
name
city
area
category
source_url
google_maps_url
notes
added_by
status
created_at
```

### Categories

Example categories:

```text
Food
Cafe
Shopping
Activity
Temple
Museum
Nightlife
Hotel
Transport
Other
```

### Spot Statuses

```text
Idea
Want to go
Must-do
Planned
Booked
Skipped
```

### Voting

Each user can vote on a spot:

```text
Must-do
Want
Maybe
Skip
```

### Comments

Each spot should have a comment thread so friends can discuss it.

Example:

```text
Spot: Fushimi Inari
Comment: "We should go early before it gets packed."
Vote: Must-do
```

## 4. Map View

The Map section should help users see saved spots geographically.

For version 1, each spot can store a Google Maps link and optionally latitude/longitude.

### Version 1

* Open saved Google Maps links
* Show city/category filters
* Allow users to manually paste Google Maps URLs

### Future Version

* Parse Google Maps URLs
* Store coordinates
* Show pins in an embedded map
* Import selected places from a shared Google Maps list

## 5. Plan and Itinerary

The Plan section should organize the trip by day.

### Features

* Add days to the trip
* Assign a city to each day
* Add itinerary items
* Link itinerary items to saved spots
* Add times, notes, and reservation details
* Attach documents to itinerary items

### Example

```text
Nov 12 — Tokyo

10:00 AM — TeamLab Borderless
1:00 PM — Lunch in Ginza
3:00 PM — Shopping in Shibuya
8:00 PM — Shinjuku food/drinks
```

### Itinerary Item Fields

```text
day_id
spot_id optional
title
start_time optional
end_time optional
location
confirmation_link optional
notes
```

## 6. Travel Section

The Travel section stores structured travel information.

Possible subsections:

```text
Flights
Hotels
Trains
Tickets
Reservations
```

This section overlaps with Documents, but the difference is:

* Documents stores files.
* Travel stores structured trip items.

Example:

```text
Flight
- Airline
- Confirmation number
- Departure airport
- Arrival airport
- Departure time
- Arrival time
- Attached PDF
```

Example:

```text
Hotel
- Hotel name
- Address
- Check-in date
- Check-out date
- Confirmation number
- Attached PDF
```

For version 1, Travel can be simple and document-focused.

## 7. Documents

The Documents section is for storing important files.

Examples:

* Hotel PDFs
* Flight PDFs
* Train tickets
* Attraction tickets
* Reservation confirmations
* Insurance forms
* Receipts
* Screenshots
* Miscellaneous travel documents

### Document Fields

```text
trip_id
title
type
file_url
uploaded_by
related_day_id optional
related_spot_id optional
related_travel_item_id optional
amount optional
currency optional
paid_by optional
notes
created_at
```

### Document Types

```text
Hotel
Flight
Train
Ticket
Reservation
Receipt
Insurance
Form
Screenshot
Other
```

## 8. Receipts and Expense Splitting

The Receipts section should work like a small built-in Splitwise-style feature.

Users can add expenses and split them between selected trip members.

### Receipt Fields

```text
trip_id
title
amount
currency
paid_by_user_id
category
date
notes optional
receipt_file_url optional
created_by
created_at
```

### Split Methods

Version 1 should support:

```text
Equal split
Custom amount split
```

Future versions can support:

```text
Split by percentage
Split by shares
Recurring expense
Currency conversion
```

### Add Receipt Flow

```text
Title
Amount
Currency
Paid by
Date
Category
Attach receipt image/PDF
Split with selected members
Choose split method
Add notes
Save
```

### Expense Example

Alex pays ¥8,400 for ramen dinner split between 4 people.

```text
Total: ¥8,400
Split between: 4 people
Each share: ¥2,100

You owe Alex: ¥2,100
Matt owes Alex: ¥2,100
Josh owes Alex: ¥2,100
Alex paid their own share
```

### Balance Summary

The app should calculate:

* Who I owe
* Who owes me
* Total group balances
* Suggested settle-up payments

Example:

```text
You owe:
- Alex: ¥3,200

You are owed:
- Josh: ¥5,000
- Matt: ¥2,100
```

## 9. Cash / ATM Withdrawals

The Cash section tracks ATM withdrawals and cash handed out to friends.

This is useful when one person repeatedly withdraws cash for the group.

### Use Case

One person has a card with no foreign exchange fees and withdraws yen for everyone.

Example:

```text
ATM Withdrawal
Amount: ¥50,000
Withdrawn by: You
ATM fee: ¥220
Date: Nov 10
Receipt photo attached
```

Then the user records how much cash was handed to each person:

```text
Alex received: ¥15,000
Matt received: ¥15,000
Josh received: ¥10,000
You kept: ¥10,000
```

This creates balances:

```text
Alex owes you ¥15,000
Matt owes you ¥15,000
Josh owes you ¥10,000
```

### Cash Withdrawal Fields

```text
trip_id
withdrawn_by_user_id
amount
currency
atm_fee_amount optional
date
notes optional
receipt_file_url optional
created_at
```

### Cash Distribution Fields

```text
withdrawal_id
received_by_user_id
amount
currency
```

### Important Rule

A withdrawal itself is not automatically a group expense.

Debt is created when:

```text
Cash is given to another person
```

or

```text
The withdrawn cash is used to pay for a shared expense
```

## 10. Settle Up

The Settle Up section should combine:

* Receipt splits
* Cash distributions
* Settlements already paid

The app should show simplified balances.

### Example

```text
Suggested settlements:

Alex pays you ¥12,900
Matt pays you ¥8,400
Josh pays you ¥11,200
```

Users should be able to mark payments as settled.

### Settlement Fields

```text
trip_id
from_user_id
to_user_id
amount
currency
note optional
created_at
```

## Data Model Draft

### users

```text
id
display_name
email
avatar_url optional
created_at
```

### trips

```text
id
name
destination
start_date
end_date
invite_code
created_by
created_at
```

### trip_members

```text
trip_id
user_id
role
joined_at
```

### spots

```text
id
trip_id
name
city
area optional
category
google_maps_url optional
source_url optional
latitude optional
longitude optional
notes optional
status
added_by
created_at
updated_at
```

### spot_votes

```text
id
spot_id
user_id
vote
created_at
updated_at
```

### spot_comments

```text
id
spot_id
user_id
comment
created_at
updated_at
```

### links

```text
id
trip_id
title
url
source_type
notes optional
related_spot_id optional
added_by
created_at
updated_at
```

### itinerary_days

```text
id
trip_id
date
city optional
notes optional
created_at
```

### itinerary_items

```text
id
day_id
spot_id optional
title
start_time optional
end_time optional
location optional
confirmation_link optional
notes optional
created_at
updated_at
```

### travel_items

```text
id
trip_id
type
title
start_datetime optional
end_datetime optional
location optional
confirmation_number optional
notes optional
created_by
created_at
updated_at
```

### documents

```text
id
trip_id
title
type
file_url
uploaded_by
related_day_id optional
related_spot_id optional
related_travel_item_id optional
amount optional
currency optional
paid_by_user_id optional
notes optional
created_at
```

### expenses

```text
id
trip_id
title
amount
currency
paid_by_user_id
category
date
notes optional
receipt_file_url optional
created_by
created_at
updated_at
```

### expense_splits

```text
id
expense_id
user_id
amount_owed
is_settled
settled_at optional
created_at
```

### cash_withdrawals

```text
id
trip_id
withdrawn_by_user_id
amount
currency
atm_fee_amount optional
date
notes optional
receipt_file_url optional
created_at
```

### cash_distributions

```text
id
withdrawal_id
received_by_user_id
amount
currency
created_at
```

### settlements

```text
id
trip_id
from_user_id
to_user_id
amount
currency
note optional
created_at
```

### incoming_shares

Optional table for debugging or saved drafts from Android share intents.

```text
id
user_id
trip_id optional
content_type
raw_text optional
file_url optional
suggested_destination optional
processed
created_at
```

## Suggested App Navigation

### Mobile Navigation

```text
Bottom tabs:
Spots | Plan | Money | Docs | More
```

### More Tab

```text
Members
Invite Friends
Cash / ATM
Settle Up
Settings
```

### Desktop Navigation

```text
Left sidebar:
Home
Spots
Links
Map
Plan
Travel
Money
Documents
Members
Settings
```

## Responsive Design Requirements

Each major screen should support both mobile and desktop layouts.

### Mobile

* Single-column layout
* Bottom navigation
* Cards stacked vertically
* Tap item to open detail screen
* Large primary actions
* Easy one-handed use

### Desktop Web

* Sidebar navigation
* Wider content area
* Two-column layouts where useful
* List/detail patterns
* Tables for receipts, documents, and cash history
* Persistent detail panels for selected items

### Example Responsive Pattern

Receipts screen:

```text
Mobile:
Balance summary
Add receipt button
Receipt cards
Tap receipt → detail screen

Desktop:
Sidebar navigation
Receipt list/table on left
Selected receipt detail panel on right
Balance summary visible at top
```

## MVP Scope

The first version should focus on the features that make the app useful before the trip.

### MVP Features

```text
Authentication
Create trip
Join trip with invite code/link
Trip members
Spots/link board
Spot comments
Spot votes
Basic document upload
Receipts with equal split
Cash withdrawal tracking
Balance summary
Responsive Android and desktop web UI
```

### Post-MVP Features

```text
Android native share target
Custom receipt splits
Itinerary day planner
Travel item details for flights/hotels/trains
Map pins
Google Maps list import helper
Settlement suggestions
Receipt OCR
Currency conversion
Offline mode
Push notifications
Better role permissions
```

## Suggested Build Order

1. Set up Flutter project
2. Build responsive app shell/navigation
3. Create mock UI screens
4. Set up Supabase project
5. Implement authentication
6. Create trips
7. Join trips with invite code
8. Add trip members
9. Build Spots section
10. Add comments and votes
11. Build Documents upload
12. Build Receipts section with equal splitting
13. Build Cash / ATM section
14. Build balance calculation
15. Build Settle Up screen
16. Add Android native share target
17. Add Itinerary
18. Add Travel section
19. Polish UI and responsive desktop layouts

## Design Workflow

The UI should be designed before implementing the full app.

Recommended workflow:

```text
1. Generate mobile and desktop mockups using Figma AI or Claude Design
2. Export screenshots for each major screen
3. Write a short spec for each screen
4. Implement one screen at a time in Flutter
5. Extract repeated UI into reusable widgets
6. Connect screens to Supabase data
```

## Screens to Design

Design both mobile and desktop versions for:

```text
1. Welcome / Auth
2. Create Trip
3. Join Trip
4. Trip Home
5. Spots Board
6. Spot Detail
7. Incoming Share
8. Map View
9. Plan / Itinerary
10. Travel
11. Receipts
12. Add Receipt
13. Cash / ATM
14. Add ATM Withdrawal
15. Documents
16. Document Detail
17. Settle Up
18. Members
19. Settings
```

## Reusable Flutter Widgets

Potential reusable widgets:

```text
AppShell
ResponsiveScaffold
TripCard
SpotCard
LinkPreviewCard
VoteChip
CommentThread
ReceiptCard
SplitMemberRow
BalanceSummaryCard
CashWithdrawalCard
CashDistributionRow
DocumentTile
TravelItemCard
ItineraryDayCard
MemberAvatarRow
IncomingShareCard
PrimaryActionButton
EmptyState
LoadingState
ErrorState
```

## Design Style Direction

The app should feel:

* Clean
* Modern
* Friendly
* Travel-focused
* Organized
* Lightweight
* Easy to use while walking around or tired during travel

Recommended visual style:

```text
Warm cream background
Charcoal text
Terracotta primary accent
Sage green secondary accent
Muted gold highlights
Soft white cards
Rounded corners
Subtle shadows
Simple line icons
Large touch targets
```

Suggested color palette:

```text
Background: #F8F3EA
Surface/Card: #FFFDF8
Primary: #C96F4A
Primary Dark: #9F4F34
Secondary: #7D9A75
Accent: #D6A84F
Text Primary: #2F2A25
Text Secondary: #6F665D
Border: #E6DCCF
Success: #4F8A5B
Warning: #C98A2E
Danger: #B94A48
```

## Notes

This project is intentionally small in user count but broad in features. The goal is not to build a commercial travel app immediately. The goal is to create a useful private tool and gain practical experience building a real full-stack app.

The app should prioritize simplicity, maintainability, and usefulness over feature complexity.

---

## Setup & Build

### Prerequisites

- Flutter SDK (stable)
- Android SDK with `adb` on PATH (or use the full adb path)
- A Supabase project

### Environment

Create a `.env` file in the project root (never commit this file):

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

See `.env.example` for the required keys. The anon key is safe for client-side use — it is protected by Row Level Security policies.

### Run (development)

```bash
flutter run --dart-define-from-file=.env
```

### Build (release APK)

```bash
flutter build apk --dart-define-from-file=.env
```

The APK is output to `build/app/outputs/flutter-apk/app-release.apk`.

### Install to a connected Android device

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

### Required Supabase migrations

Run the migration files in order in the Supabase SQL editor:

1. `supabase/migrations/001_initial_schema.sql` — base schema (trips, spots, docs, money, travel, plan)
2. `supabase/migrations/002_trip_invites.sql` — invite codes + RPCs
3. `supabase/migrations/003_rls_fixes_and_settlements.sql` — RLS fixes, settlements table, trip_links table, ownership transfer RPC
4. `supabase/migrations/004_activity_events_and_travel_status.sql` — activity feed table + triggers, travel_items.status column
