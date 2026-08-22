import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/customer_service/customer_service_webview_file_selector.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/customer_service_url_builder.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// 在线客服 H5 WebView（需启用 JavaScript）。
class CustomerServiceWebView extends StatefulWidget {
  const CustomerServiceWebView({
    super.key,
    required this.url,
    this.onPageLoaded,
    this.onPageLoadStarted,
  });

  final String url;
  final VoidCallback? onPageLoaded;
  final VoidCallback? onPageLoadStarted;

  @override
  State<CustomerServiceWebView> createState() => _CustomerServiceWebViewState();
}

class _CustomerServiceWebViewState extends State<CustomerServiceWebView> {
  WebViewController? _controller;
  bool _mainFrameFailed = false;
  bool _loadedSignaled = false;
  Timer? _loadedSignalTimer;

  /// 仅防止滚动链传递到 Flutter 外层，不锁定 H5 自身滚动。
  static const String _overscrollContainScript = '''
(function() {
  var styleId = 'customer-service-scroll-fix';
  if (document.getElementById(styleId)) return;
  var style = document.createElement('style');
  style.id = styleId;
  style.textContent = 'html, body { overscroll-behavior: contain; -webkit-overflow-scrolling: touch; }';
  document.head.appendChild(style);
})();
''';

  bool get _isWebKitPlatform =>
      !kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform;

  @override
  void initState() {
    super.initState();
    final initialUri = CustomerServiceUrlBuilder.parseLoadableUri(widget.url);
    if (initialUri == null) {
      return;
    }
    if (kDebugMode) {
      debugPrint('CUSTOMER_SERVICE url: $initialUri');
    }
    _controller = _createController(initialUri);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAndroidWebViewBackground();
  }

  @override
  void dispose() {
    _loadedSignalTimer?.cancel();
    super.dispose();
  }

  /// Android WebView 底层色随主题变化，避免深色模式闪白底。
  void _syncAndroidWebViewBackground() {
    final controller = _controller;
    if (controller == null) return;
    if (kIsWeb || WebViewPlatform.instance is! AndroidWebViewPlatform) {
      return;
    }
    final dark = settingsIsDark(context);
    controller.setBackgroundColor(AppColors.background(dark: dark));
  }

  WebViewController _createController(Uri initialUri) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        javaScriptCanOpenWindowsAutomatically: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);
    // iOS 上 setBackgroundColor 会把 WKWebView 设为非不透明，弹窗内易白屏。
    // Android 背景色在 didChangeDependencies 里按日夜主题同步。

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }
            final scheme = uri.scheme.toLowerCase();
            if (scheme != 'http' && scheme != 'https') {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onProgress: (progress) {
            if (progress >= 90) {
              _scheduleLoadedSignal();
            }
          },
          onPageFinished: (_) => _onPageFinished(controller),
          onWebResourceError: (error) {
            if (kDebugMode) {
              debugPrint(
                'CUSTOMER_SERVICE web error: ${error.errorCode} '
                '${error.description} mainFrame=${error.isForMainFrame}',
              );
            }
            if (error.isForMainFrame == true) {
              _mainFrameFailed = true;
              _loadedSignalTimer?.cancel();
              if (!_loadedSignaled) {
                _loadedSignaled = true;
                widget.onPageLoaded?.call();
              }
              if (mounted) {
                setState(() {});
              }
            }
          },
        ),
      );

    if (controller.platform is AndroidWebViewController) {
      if (kDebugMode) {
        AndroidWebViewController.enableDebugging(true);
      }
      final androidController =
          controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      unawaited(
        CustomerServiceWebViewFileSelector.attachToAndroidController(
          controller: androidController,
          context: context,
        ),
      );
    }

    controller.loadRequest(initialUri);

    return controller;
  }

  Future<void> _onPageFinished(WebViewController controller) async {
    try {
      await controller.runJavaScript(_overscrollContainScript);
    } catch (_) {}
    if (!mounted || _mainFrameFailed) {
      return;
    }
    _scheduleLoadedSignal();
  }

  void _scheduleLoadedSignal() {
    if (_loadedSignaled || _mainFrameFailed) {
      return;
    }
    _loadedSignalTimer?.cancel();
    final delay = _isWebKitPlatform
        ? const Duration(milliseconds: 150)
        : Duration.zero;
    _loadedSignalTimer = Timer(delay, () {
      if (!mounted || _loadedSignaled || _mainFrameFailed) {
        return;
      }
      _loadedSignaled = true;
      widget.onPageLoaded?.call();
    });
  }

  Future<void> _reload() async {
    final controller = _controller;
    final initialUri = CustomerServiceUrlBuilder.parseLoadableUri(widget.url);
    if (controller == null || initialUri == null) {
      return;
    }
    setState(() {
      _mainFrameFailed = false;
      _loadedSignaled = false;
    });
    widget.onPageLoadStarted?.call();
    await controller.loadRequest(initialUri);
  }

  Widget _buildWebView(WebViewController controller) {
    if (!kIsWeb && controller.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: controller.platform as AndroidWebViewController,
          displayWithHybridComposition: true,
        ),
      );
    }

    if (!kIsWeb && controller.platform is WebKitWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: WebKitWebViewWidgetCreationParams(
          controller: controller.platform as WebKitWebViewController,
        ),
      );
    }

    return WebViewWidget(controller: controller);
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final i18n = AppI18n.of(context);
    final initialUri = CustomerServiceUrlBuilder.parseLoadableUri(widget.url);
    final controller = _controller;

    if (initialUri == null) {
      return Center(
        child: Text(
          i18n.t(
            zhHans: '客服链接无效，仅支持 HTTP/HTTPS',
            zhHant: '客服連結無效，僅支援 HTTP/HTTPS',
            en: 'Invalid customer service link. Only HTTP/HTTPS is supported.',
            ja: 'カスタマーサポートのリンクが無効です。HTTP/HTTPS のみ対応しています。',
            ko: '고객센터 링크가 올바르지 않습니다. HTTP/HTTPS만 지원합니다.',
          ),
          style: TextStyle(
            color: AppColors.subText(dark: dark),
            fontSize: 15,
          ),
        ),
      );
    }

    final shellColor = AppColors.background(dark: dark);

    if (controller == null) {
      return ColoredBox(color: shellColor);
    }

    if (_mainFrameFailed) {
      return ColoredBox(
        color: shellColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  i18n.t(
                    zhHans: '客服页面加载失败，请稍后重试',
                    zhHant: '客服頁面載入失敗，請稍後重試',
                    en: 'Failed to load customer service. Please try again later.',
                    ja: 'カスタマーサポートページの読み込みに失敗しました。',
                    ko: '고객센터 페이지를 불러오지 못했습니다.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subText(dark: dark),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _reload,
                  child: Text(i18n.t(
                    zhHans: '重试',
                    zhHant: '重試',
                    en: 'Retry',
                    ja: '再試行',
                    ko: '다시 시도',
                  )),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: shellColor,
      child: SizedBox.expand(child: _buildWebView(controller)),
    );
  }
}
