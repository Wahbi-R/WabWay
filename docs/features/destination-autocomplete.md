# Destination Autocomplete

## Description

A local ~110-entry country/city dataset powering `RawAutocomplete` in the trip-create and trip-settings flows. Requires no paid APIs or network calls.

## Key Files

- `lib/data/destinations.dart` — static `kDestinations` list (countries and major cities)
- `lib/screens/home_screen.dart` — create-trip sheet uses `RawAutocomplete`
- `lib/screens/more_screen.dart` (trip settings sheet) — same autocomplete widget

## How It Works

`RawAutocomplete` filters `kDestinations` with a case-insensitive `contains` check against the user's current input. Suggestions appear in a floating overlay limited to 6 results. Selecting a suggestion fills the destination text field. The dataset is entirely local — no debounce or HTTP request is involved.

## Setup

No external setup required. The dataset lives in `lib/data/destinations.dart` and can be extended freely.
