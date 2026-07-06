import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/places/google_maps_parser.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

/// Loads a Google Maps list URL in a WebView, waits for JS to render,
/// then scrapes the fully-rendered DOM for place data.
///
/// Calls [onResult] with extracted places (empty list = nothing found).
/// Shows the WebView at reduced size so the user can see it loading.
class MapsWebScrapeScreen extends StatefulWidget {
  const MapsWebScrapeScreen({
    super.key,
    required this.url,
    required this.onResult,
  });

  final String                        url;
  final ValueChanged<List<MapsPlace>> onResult;

  @override
  State<MapsWebScrapeScreen> createState() => _MapsWebScrapeScreenState();
}

class _MapsWebScrapeScreenState extends State<MapsWebScrapeScreen> {
  late final WebViewController _wvc;
  String  _status  = 'Opening Google Maps…';
  bool    _scraped = false;
  double  _progress = 0;

  // Mobile UA so Maps serves the list view (not desktop map)
  static const _ua =
      'Mozilla/5.0 (Linux; Android 14; SM-S948W) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  @override
  void initState() {
    super.initState();
    _wvc = WebViewController()
      ..setUserAgent(_ua)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() {
          _progress = p / 100.0;
          if (p < 100) _status = 'Loading page ($p%)…';
        }),
        onPageFinished: (_) {
          setState(() => _status = 'Page loaded — waiting for list…');
          _scheduleScrape();
        },
        onWebResourceError: (e) {
          if (!_scraped) {
            _scraped = true;
            widget.onResult([]);
          }
        },
      ))
      ..loadRequest(
        Uri.parse(widget.url),
        headers: {'Accept-Language': 'en-US,en;q=0.9'},
      );
  }

  void _scheduleScrape() {
    // 5 s: enough for Maps XHR calls to finish and render list items
    Future.delayed(const Duration(seconds: 5), _scrape);
  }

  Future<void> _scrape() async {
    if (_scraped || !mounted) return;
    _scraped = true;
    setState(() => _status = 'Scanning for places…');

    try {
      final raw = await _wvc.runJavaScriptReturningResult(r'''
        (function() {
          var out = [];
          var seen = {};

          function tryAdd(name, lat, lon) {
            lat = parseFloat(lat); lon = parseFloat(lon);
            if (isNaN(lat)||isNaN(lon)) return;
            if (Math.abs(lat)>90||Math.abs(lon)>180) return;
            if (lat===0&&lon===0) return;
            var key = lat.toFixed(4)+','+lon.toFixed(4);
            if (seen[key]) return;
            seen[key] = true;
            out.push({name: String(name).replace(/\\\\n/g,' ').trim(), lat:lat, lon:lon});
          }

          // Gather text from every <script> tag (data blobs live here, not in rendered DOM)
          var scriptText = '';
          var scripts = document.querySelectorAll('script');
          for (var i = 0; i < scripts.length; i++) {
            scriptText += scripts[i].textContent || '';
          }
          var allText = document.documentElement.innerHTML + scriptText;

          var m, re;

          // Pattern A  ["Name",null,null,[[lat,lon  (Google list data blob)
          re = /\["([^"\\]{2,80})",null,null,\[\[([-\d.]+),([-\d.]+)/g;
          while ((m=re.exec(allText))!==null && out.length<60) tryAdd(m[1],m[2],m[3]);

          // Pattern B  ["Name"...,"Name",...3d{lat}!4d{lon}  (place data embedded in URL strings)
          if (out.length === 0) {
            re = /"([^"\\]{2,60})"[^[\]]{0,400}!3d([-\d.]+)!4d([-\d.]+)/g;
            while ((m=re.exec(allText))!==null && out.length<60) tryAdd(m[1],m[2],m[3]);
          }

          // Pattern C  raw @lat,lon anchor text near a quoted name
          if (out.length === 0) {
            re = /"([^"\\]{2,60})"[^[\]]{0,200}@([-\d.]+),([-\d.]+)/g;
            while ((m=re.exec(allText))!==null && out.length<60) tryAdd(m[1],m[2],m[3]);
          }

          // Pattern D  coordinate pair as plain numbers near a name (integers × 1e7)
          if (out.length === 0) {
            re = /"([^"\\]{2,60})"[^[\]]{0,300}\[(\d{8,10}),(\d{8,11})\]/g;
            while ((m=re.exec(allText))!==null && out.length<60) {
              tryAdd(m[1], parseInt(m[2])/1e7, parseInt(m[3])/1e7);
            }
          }

          // Pattern E  last resort: rendered DOM text + any lat/lon near it
          // Grab visible text nodes from the bottom sheet / list cards
          if (out.length === 0) {
            var latLonRe = /\b([-]?\d{1,3}\.\d{4,}),([-]?\d{1,3}\.\d{4,})\b/g;
            var coordsInPage = [];
            var cl;
            while ((cl=latLonRe.exec(allText))!==null) {
              var lt=parseFloat(cl[1]),ln=parseFloat(cl[2]);
              if (Math.abs(lt)<=90&&Math.abs(ln)<=180&&!(lt===0&&ln===0)) coordsInPage.push([lt,ln]);
            }
            // Names: h3/h4 visible text, aria-label attributes
            var nameEls = document.querySelectorAll('h3,h4,[aria-label],[data-place-id]');
            var names = [];
            nameEls.forEach(function(el) {
              var t = (el.getAttribute('aria-label') || el.innerText || '').trim();
              if (t.length >= 2 && t.length <= 80 && !seen[t]) { names.push(t); seen[t]=true; }
            });
            for (var ni = 0; ni < names.length && ni < coordsInPage.length; ni++) {
              var lt=coordsInPage[ni][0], ln=coordsInPage[ni][1];
              var key=lt.toFixed(4)+','+ln.toFixed(4);
              if (!seen[key]) { seen[key]=true; out.push({name:names[ni],lat:lt,lon:ln}); }
            }
          }

          return JSON.stringify(out);
        })()
      ''');

      final places = _parseScrapeResult(raw.toString());
      if (mounted) widget.onResult(places);
    } catch (_) {
      if (mounted) widget.onResult([]);
    }
  }

  List<MapsPlace> _parseScrapeResult(String raw) {
    // runJavaScriptReturningResult wraps strings in extra quotes on some platforms
    String json = raw;
    if (json.startsWith('"') && json.endsWith('"')) {
      json = jsonDecode(json) as String;
    }
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return list.map((m) => MapsPlace(
          name:     m['name'] as String,
          lat:      (m['lat'] as num).toDouble(),
          lon:      (m['lon'] as num).toDouble(),
          category: SpotCategory.landmark,
        )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Scanning list', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _scraped = true; // prevent callback after pop
            widget.onResult([]);
          },
        ),
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            color: const Color(0xFFE8EEF6),
            padding: const EdgeInsets.symmetric(
                horizontal: kSpace4, vertical: kSpace3),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4A7AB5),
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Text(_status,
                      style: kStyleCaption
                          .copyWith(color: const Color(0xFF4A7AB5))),
                ),
              ],
            ),
          ),
          if (_progress > 0 && _progress < 1)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: kColorBorder,
              color: const Color(0xFF4A7AB5),
              minHeight: 2,
            ),
          // WebView fills remaining space so the user can see it loading
          Expanded(
            child: WebViewWidget(controller: _wvc),
          ),
        ],
      ),
    );
  }
}
