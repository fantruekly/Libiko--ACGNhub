import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the external browser. Returns false when [url] is empty,
/// malformed, or the platform refuses to launch it.
Future<bool> openExternalUrl(String url) async {
  if (url.isEmpty) return false;
  try {
    return await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
