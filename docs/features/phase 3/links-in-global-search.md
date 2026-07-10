# Links in Global Search (Build 79)

## Summary

Saved links now appear as results in global search. Searching by title, domain, URL, or notes surfaces matching links under a "Links" section; tapping a result opens the URL directly in the external browser.

## What changed

- **`lib/screens/global_search_screen.dart`**
  - Added imports for `url_launcher`, `LinksService`, and `links_data.dart`
  - Added `_ResultKind.link` to the result kind enum
  - Added `List<TripLink> _links = []` to state
  - Added `LinksService.loadLinks(widget.tripId)` to the parallel `Future.wait` fetch (index 7)
  - Added search loop matching `link.title`, `link.domain`, `link.url`, and `link.notes`
  - Tapping a link result calls `launchUrl` in `LaunchMode.externalApplication`
  - Added `'Links'` to the `_kindLabel` map
  - Updated empty-state placeholder text to mention links
