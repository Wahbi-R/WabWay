import '../../data/auto_link_data.dart';
import 'client.dart';

class AutoLinksService {
  static Future<Map<AutoLinkSource, List<AutoLink>>> load(String tripId) async {
    final results = await Future.wait([
      _loadSpots(tripId),
      _loadShopping(tripId),
      _loadItinerary(tripId),
      _loadTravel(tripId),
      _loadAccommodations(tripId),
    ]);

    final map = <AutoLinkSource, List<AutoLink>>{};
    const sources = AutoLinkSource.values;
    for (var i = 0; i < sources.length; i++) {
      if (results[i].isNotEmpty) map[sources[i]] = results[i];
    }
    return map;
  }

  static Future<List<AutoLink>> _loadSpots(String tripId) async {
    final rows = await supabase
        .from('spots')
        .select('id, name, source_url')
        .eq('trip_id', tripId)
        .not('source_url', 'is', null)
        .neq('source_url', '');
    return (rows as List)
        .map((r) => AutoLink(
              source: AutoLinkSource.spot,
              itemId: r['id'] as String,
              itemName: (r['name'] as String?) ?? '',
              url: r['source_url'] as String,
            ))
        .toList();
  }

  static Future<List<AutoLink>> _loadShopping(String tripId) async {
    final rows = await supabase
        .from('shopping_items')
        .select('id, name, link_url')
        .eq('trip_id', tripId)
        .not('link_url', 'is', null)
        .neq('link_url', '');
    return (rows as List)
        .map((r) => AutoLink(
              source: AutoLinkSource.shopping,
              itemId: r['id'] as String,
              itemName: (r['name'] as String?) ?? '',
              url: r['link_url'] as String,
            ))
        .toList();
  }

  static Future<List<AutoLink>> _loadItinerary(String tripId) async {
    final rows = await supabase
        .from('itinerary_items')
        .select('id, title, confirmation_url')
        .eq('trip_id', tripId)
        .not('confirmation_url', 'is', null)
        .neq('confirmation_url', '');
    return (rows as List)
        .map((r) => AutoLink(
              source: AutoLinkSource.itinerary,
              itemId: r['id'] as String,
              itemName: (r['title'] as String?) ?? '',
              url: r['confirmation_url'] as String,
            ))
        .toList();
  }

  static Future<List<AutoLink>> _loadTravel(String tripId) async {
    final rows = await supabase
        .from('travel_items')
        .select('id, title, url')
        .eq('trip_id', tripId)
        .not('url', 'is', null)
        .neq('url', '');
    return (rows as List)
        .map((r) => AutoLink(
              source: AutoLinkSource.travel,
              itemId: r['id'] as String,
              itemName: (r['title'] as String?) ?? '',
              url: r['url'] as String,
            ))
        .toList();
  }

  static Future<List<AutoLink>> _loadAccommodations(String tripId) async {
    final rows = await supabase
        .from('accommodations')
        .select('id, name, url')
        .eq('trip_id', tripId)
        .not('url', 'is', null)
        .neq('url', '');
    return (rows as List)
        .map((r) => AutoLink(
              source: AutoLinkSource.accommodation,
              itemId: r['id'] as String,
              itemName: (r['name'] as String?) ?? '',
              url: r['url'] as String,
            ))
        .toList();
  }
}
