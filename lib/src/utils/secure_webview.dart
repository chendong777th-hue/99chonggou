import 'package:webview_flutter/webview_flutter.dart';

class SecureWebViewPolicy {
  const SecureWebViewPolicy._();

  static Uri? parseInitialUri(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.trim().isEmpty) {
      return null;
    }
    return uri;
  }

  static NavigationDelegate navigationDelegate({
    required Uri initialUri,
  }) {
    return NavigationDelegate(
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) {
          return NavigationDecision.prevent;
        }
        if (uri.scheme != 'https') {
          return NavigationDecision.prevent;
        }
        if (uri.host.trim() != initialUri.host.trim()) {
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    );
  }
}
