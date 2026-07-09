import 'dart:convert';
import 'package:http/http.dart' as http;

// Set by SocialPlaceExtractor when the audio server URL is known.
// Allows OembedService to proxy Instagram/TikTok caption fetching through
// the phone server (no CORS restrictions there).
String? _proxyBaseUrl;

class OembedResult {
  const OembedResult({required this.title, this.thumbnailUrl});
  final String  title;
  final String? thumbnailUrl;
}

abstract final class OembedService {
  static const _ua = 'WabWay/1.1 (wahbi@portalprints.com)';
  static const _browserUa =
      'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  /// Set the audio server base URL so caption requests can be proxied
  /// through it, bypassing browser CORS restrictions.
  static void setProxyUrl(String? url) => _proxyBaseUrl = url;

  static Future<OembedResult?> fetch(String url) async {
    // Try server-side proxy first (avoids CORS on web)
    final proxy = _proxyBaseUrl;
    if (proxy != null && proxy.isNotEmpty) {
      final result = await _proxyCaption(proxy, url);
      if (result != null) return result;
    }
    if (url.contains('tiktok.com'))    return _tiktok(url);
    if (url.contains('instagram.com')) return _instagram(url);
    return null;
  }

  // ── Server-side proxy ─────────────────────────────────────────────────────

  static Future<OembedResult?> _proxyCaption(String baseUrl, String url) async {
    try {
      final endpoint = Uri.parse(
        '$baseUrl/caption?url=${Uri.encodeComponent(url)}',
      );
      final res = await http
          .get(endpoint, headers: {'User-Agent': _ua})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final caption = (j['caption'] as String? ?? '').trim();
      if (caption.isEmpty) return null;
      return OembedResult(title: caption);
    } catch (_) {
      return null;
    }
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

  // ── Instagram ─────────────────────────────────────────────────────────────
  // Strategy:
  //   1. Fetch /p/CODE/embed/captioned/ — public embed page has the full caption
  //   2. Fall back to og:description from the main page (usually truncated)

  static Future<OembedResult?> _instagram(String url) async {
    final shortcode = RegExp(
      r'instagram\.com/(?:p|reel|tv)/([A-Za-z0-9_-]+)',
    ).firstMatch(url)?.group(1);

    // 1. Embed page
    if (shortcode != null) {
      final result = await _instagramEmbed(shortcode);
      if (result != null) return result;
    }

    // 2. Main page OG fallback
    return _instagramOg(url);
  }

  static Future<OembedResult?> _instagramEmbed(String shortcode) async {
    try {
      final embedUrl = 'https://www.instagram.com/p/$shortcode/embed/captioned/';
      final res = await http.get(Uri.parse(embedUrl), headers: {
        'User-Agent': _browserUa,
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'en-US,en;q=0.9',
      }).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) return null;
      final html = res.body;

      // Try to pull caption from the Caption div
      final caption = _captionFromEmbedHtml(html);

      // Thumbnail from og:image in embed page
      final thumb = _ogTag(html, 'og:image');

      if (caption == null || caption.isEmpty) return null;
      return OembedResult(title: caption, thumbnailUrl: thumb);
    } catch (_) {
      return null;
    }
  }

  // Parses the caption text out of Instagram's embed page HTML.
  static String? _captionFromEmbedHtml(String html) {
    // The embed page wraps the caption in class="Caption"
    final captionBlock = RegExp(
      r'''class=["']Caption["'][^>]*>([\s\S]*?)(?:<div\s+class=["']CaptionComments|<\/div>\s*<\/div>\s*<div\s+class=["']EmbedFooter)''',
    ).firstMatch(html)?.group(1);

    if (captionBlock != null) {
      // Strip the leading username div
      var text = captionBlock.replaceFirst(
        RegExp(r'^[\s\S]*?<\/div>\s*', dotAll: true),
        '',
      );
      text = _stripTags(text);
      text = _decodeEntities(text).replaceAll(RegExp(r' +'), ' ').trim();
      if (text.length > 10) return text;
    }

    // Fallback: look for caption in JSON blob embedded in the page
    final jsonCaption = RegExp(
      r'"caption"\s*:\s*"((?:[^"\\]|\\.)*)"',
    ).firstMatch(html)?.group(1);
    if (jsonCaption != null && jsonCaption.length > 5) {
      return _decodeEntities(
        jsonCaption
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"'),
      ).trim();
    }

    return null;
  }

  static Future<OembedResult?> _instagramOg(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'facebookexternalhit/1.1',
      }).timeout(const Duration(seconds: 10));
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String? _ogTag(String html, String property) {
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

  static String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '');

  static String _decodeEntities(String s) => s
      .replaceAll('&amp;',  '&')
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;',  "'")
      .replaceAll('&nbsp;', ' ');
}
