import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared image cache: max 150 files, 14-day TTL, LRU eviction.
/// ~45 MB ceiling at 300 KB average — covers avatars, trip covers, and photos
/// without burning unreasonable storage.
class WabwayImageCache {
  static const _key = 'wabwayImages';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 150,
    ),
  );
}
