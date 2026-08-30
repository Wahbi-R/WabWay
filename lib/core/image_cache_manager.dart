import 'package:cached_network_image_ce/cached_network_image.dart';

/// Shared image cache: max 600 files, 14-day TTL, LRU eviction.
class WabwayImageCache {
  static final DefaultCacheManager instance = DefaultCacheManager(
    stalePeriod: const Duration(days: 14),
    maxNrOfCacheObjects: 600,
  );
}
