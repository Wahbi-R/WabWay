import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nominatim_service.dart';
import 'oembed_service.dart';

// URL of the WabWay audio server (wabway-server/ project running on G8 via Termux).
// Set via --dart-define-from-file=.env. Empty string disables the audio banner.
const _kAudioServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '');

// Tell OembedService about the proxy URL so it can route caption fetching
// through the phone server (avoids CORS on web builds).
final bool _proxyInit = () {
  OembedService.setProxyUrl(_kAudioServerUrl.isNotEmpty ? _kAudioServerUrl : null);
  return true;
}();

class SocialPlaceResult {
  const SocialPlaceResult({
    required this.caption,
    required this.places,
  });
  final String              caption;
  final List<NominatimPlace> places;
}

abstract final class SocialPlaceExtractor {
  /// Whether the audio server is configured (controls banner visibility).
  static bool get audioServerAvailable => _kAudioServerUrl.isNotEmpty;

  /// Downloads the video audio, transcribes it on the G8 server, and geocodes
  /// any place names extracted by spaCy NER. Returns null if the server is
  /// unreachable or the video can't be downloaded.
  static Future<SocialPlaceResult?> extractFromAudio(String url) async {
    if (_kAudioServerUrl.isEmpty) return null;
    try {
      final resp = await http
          .post(
            Uri.parse('$_kAudioServerUrl/transcribe'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'url': url}),
          )
          .timeout(const Duration(minutes: 3)); // transcription can take ~60s

      if (resp.statusCode != 200) return null;

      final body      = jsonDecode(resp.body) as Map<String, dynamic>;
      final transcript = (body['transcript'] as String? ?? '').trim();
      final rawPlaces  = (body['places'] as List?)?.cast<String>() ?? [];

      if (transcript.isEmpty) return null;

      // Geocode each server-extracted place name via Nominatim
      final places = <NominatimPlace>[];
      for (final name in rawPlaces.take(8)) {
        final results = await NominatimService.search(name);
        if (results.isNotEmpty) {
          final best = results.first;
          if (!places.any((p) => p.name.toLowerCase() == best.name.toLowerCase())) {
            places.add(best);
          }
        }
        if (rawPlaces.indexOf(name) < rawPlaces.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 1100));
        }
      }

      return SocialPlaceResult(caption: transcript, places: places);
    } catch (_) {
      return null;
    }
  }

  /// Extracts places from raw text (caption paste) without any network fetch.
  /// Always returns a result (never null) — places may be empty.
  static Future<SocialPlaceResult> extractFromText(String text) async {
    final candidates = _candidates(text);
    if (candidates.isEmpty) return SocialPlaceResult(caption: text, places: []);

    final places = <NominatimPlace>[];
    for (final q in candidates) {
      final results = await NominatimService.search(q);
      if (results.isNotEmpty) {
        final best = results.first;
        if (!places.any((p) => p.name.toLowerCase() == best.name.toLowerCase())) {
          places.add(best);
        }
      }
      if (candidates.indexOf(q) < candidates.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }
    return SocialPlaceResult(caption: text, places: places);
  }

  /// Fetches a TikTok/Instagram post caption and geocodes any place
  /// candidates found within it. Returns null if the post is unreachable.
  static Future<SocialPlaceResult?> extract(String url) async {
    _proxyInit; // ensure proxy URL is registered before first fetch
    final meta = await OembedService.fetch(url);
    if (meta == null) return null;

    final caption    = meta.title;
    final candidates = _candidates(caption);
    if (candidates.isEmpty) return SocialPlaceResult(caption: caption, places: []);

    final places = <NominatimPlace>[];
    for (final q in candidates) {
      final results = await NominatimService.search(q);
      if (results.isNotEmpty) {
        // Only add if not already found a very similar name
        final best = results.first;
        if (!places.any((p) =>
            p.name.toLowerCase() == best.name.toLowerCase())) {
          places.add(best);
        }
      }
      // Nominatim ToS: max 1 req/sec
      if (candidates.indexOf(q) < candidates.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }

    return SocialPlaceResult(caption: caption, places: places);
  }

  // ── Candidate extraction ──────────────────────────────────────────────────

  static List<String> _candidates(String text) {
    final found = <String>[];

    // 1. 📍 pin emoji — highest confidence
    final pinRe = RegExp(r'📍\s*([^\n#@]+)');
    for (final m in pinRe.allMatches(text)) {
      final v = m.group(1)!.trim().replaceAll(RegExp(r'[,.]$'), '');
      if (v.isNotEmpty) found.add(v);
    }

    // 2. Hashtags — strip # and CamelCase-split, skip generic travel tags
    final hashRe = RegExp(r'#(\w+)');
    for (final m in hashRe.allMatches(text)) {
      final tag = m.group(1)!;
      if (_isGenericTag(tag)) continue;
      // CamelCase → "Senso Ji Temple" style for better geocoding
      final spaced = tag.replaceAllMapped(
        RegExp(r'(?<=[a-z])(?=[A-Z])'),
        (_) => ' ',
      );
      found.add(spaced);
    }

    // Deduplicate, cap at 8 candidates
    final seen = <String>{};
    return found
        .where((s) => s.length > 3 && seen.add(s.toLowerCase()))
        .take(8)
        .toList();
  }

  static bool _isGenericTag(String tag) {
    const generic = {
      'fyp', 'foryou', 'foryoupage', 'viral', 'trending', 'explore',
      'travel', 'travelblogger', 'travelgram', 'instatravel', 'wanderlust',
      'adventure', 'vacation', 'holiday', 'trip', 'vlog', 'reels',
      'tiktok', 'instagram', 'youtube', 'shorts', 'content', 'creator',
      'photography', 'photo', 'video', 'life', 'lifestyle', 'daily',
      'love', 'beautiful', 'amazing', 'instagood', 'picoftheday',
    };
    return generic.contains(tag.toLowerCase());
  }
}
