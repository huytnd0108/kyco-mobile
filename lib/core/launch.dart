import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in the platform's external handler (browser / maps app).
/// Resolves false when nothing can handle it. Overridden in tests.
typedef UrlOpener = Future<bool> Function(Uri uri);

final urlOpenerProvider = Provider<UrlOpener>((ref) {
  return (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  };
});

/// Universal maps link for a coordinate pair (opens the maps app on Android and
/// iOS, the browser otherwise). Coordinates come from the server verbatim.
Uri mapsUri(double lat, double lng) => Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$lat,$lng',
    });

/// Hands plain text to the OS share sheet. Overridden in tests.
typedef TextSharer = Future<void> Function(String text);

final textSharerProvider = Provider<TextSharer>((ref) {
  return (text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  };
});
