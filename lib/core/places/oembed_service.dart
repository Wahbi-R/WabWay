import 'dart:convert';
import 'package:http/http.dart' as http;

class OembedResult {
  const OembedResult({required this.title, this.thumbnailUrl});
  final String  title;
  final String? thumbnailUrl;
}

abstract final class OembedService {
  static const _ua = 'WabWay/1.1 (wahbi@portalprints.com)';

  /// Fetches the post title/caption for a TikTok or Instagram URL.
  /// Returns null if the URL is unreachable or the content is private.
  static Future<OembedResult?> fetch(String url) async {
    if (url.contains('tiktok.com')) return _tiktok(url);
    if (url.contains('instagram.com')) return _instagram(url);
    return null;
  }

  // ── TikTok — free public oEmbed ───────────────────────────────────────────

  static Future<OembedResult?> _tiktok(String url) async {
    try {
      final endpoint = Uri.parse(
        'https://www.tiktok.com/oembed?url=${Uri.encodeComponent(url)}',
      );
      final res = await http
          .get(endpoint, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final title = (j['title'] as String? ?? '').trim();
      if (title.isEmpty) return null;
      return OembedResult(
        title:        title,
        thumbnailUrl: j['thumbnail_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Instagram — scrape public OG tags ────────────────────────────────────

  static Future<OembedResult?> _instagram(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url), headers: {
            'User-Agent': 'facebookexternalhit/1.1',
          })
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final html = res.body;

      final desc  = _ogTag(html, 'og:description');
      final title = _ogTag(html, 'og:title') ?? '';
      final thumb = _ogTag(html, 'og:image');

      final text = desc ?? title;
      if (text.isEmpty) return null;
      return OembedResult(
        title:        _decodeEntities(text),
        thumbnailUrl: thumb,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _ogTag(String html, String property) {
    // Matches both content="..." and content='...' variants
    final re = RegExp(
      '<meta[^>]+property=["\']$property["\'][^>]+content=["\']([^"\']*)["\']',
      caseSensitive: false,
    );
    final m = re.firstMatch(html) ??
        RegExp(
          '<meta[^>]+content=["\']([^"\']*)["\'][^>]+property=["\']$property["\']',
          caseSensitive: false,
        ).firstMatch(html);
    return m?.group(1);
  }

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;',  "'")
      .replaceAll('&nbsp;', ' ');
}
