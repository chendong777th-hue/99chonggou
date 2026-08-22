import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'package:tencent_cloud_chat_sdk/web/manager/v2_tim_conversation_manager.dart';
import 'package:tencent_cloud_chat_sdk/web/manager/v2_tim_message_manager.dart';

/// Web：按需注入 TIM JS，避免 index.html 同步阻塞 Flutter bootstrap。
///
/// 脚本 URL 稳定（无 DDC 编译 hash），浏览器可跨刷新命中 disk cache；
/// 与 Debug 下成百上千个 `*.dart.lib.js` 不同。
class TimWebScriptLoader {
  TimWebScriptLoader._();

  static Future<void>? _ensureLoadedTask;
  static final Map<String, Future<void>> _scriptLoads = <String, Future<void>>{};

  static const List<String> _scriptUrls = <String>[
    'sdk/tim-upload-plugin.js',
    'sdk/tencentcloud-chat.js',
  ];

  static Future<void> ensureLoaded() {
    return _ensureLoadedTask ??= _ensureLoadedCore();
  }

  /// 热重载 / 标签页恢复 / 长连接恢复后，强制重挂 TIM JS 会话与消息监听。
  static void rebindRealtimeListeners() {
    V2TIMConversationManager.ensureJsListenerBound(force: true);
    V2TIMMessageManager.rebindJsMessageListeners(force: true);
  }

  static Future<void> _ensureLoadedCore() async {
    if (_isTimSdkReady()) {
      return;
    }
    for (final url in _scriptUrls) {
      await _loadScript(url);
    }
    if (!_isTimSdkReady()) {
      throw StateError(
        'TIM Web SDK scripts loaded but TencentCloudChat missing',
      );
    }
  }

  static bool _isTimSdkReady() => js.context.hasProperty('TencentCloudChat');

  static Future<void> _loadScript(String url) {
    return _scriptLoads.putIfAbsent(url, () => _injectScript(url));
  }

  static Future<void> _injectScript(String url) async {
    if (url.endsWith('tencentcloud-chat.js') && _isTimSdkReady()) {
      return;
    }

    final existing = html.document.querySelector('script[src="$url"]');
    if (existing != null) {
      if (url.endsWith('tim-upload-plugin.js') ||
          (url.endsWith('tencentcloud-chat.js') && _isTimSdkReady())) {
        return;
      }
      await _waitForScriptElement(existing);
      return;
    }

    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = url
      ..async = false
      ..defer = false;
    script.onLoad.listen((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    script.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Failed to load script: $url'));
      }
    });
    html.document.body!.append(script);
    return completer.future;
  }

  static Future<void> _waitForScriptElement(html.Element script) async {
    if (_isTimSdkReady()) {
      return;
    }
    final completer = Completer<void>();
    void onLoad(_) {
      if (!completer.isCompleted) completer.complete();
    }

    void onError(_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Failed to load script: ${script.attributes['src']}'),
        );
      }
    }

    script.onLoad.listen(onLoad);
    script.onError.listen(onError);
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'Timed out loading ${script.attributes['src']}',
      ),
    );
  }
}
