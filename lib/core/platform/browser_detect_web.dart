// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool get isAndroidBrowser {
  final ua = html.window.navigator.userAgent.toLowerCase();
  // Android mobile browser: has "android", not a desktop OS
  return ua.contains('android')
      && !ua.contains('windows')
      && !ua.contains('macintosh')
      && !ua.contains('x11');
}
