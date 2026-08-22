import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 置顶闪动排查日志。控制台过滤：`[ConvPinFlicker]`
///
/// 排查完后把 [enabled] 改回 `false`。
class ConversationPinFlickerLog {
  ConversationPinFlickerLog._();

  /// 临时打开：复现置顶闪动时看 `#序号` 与 `event` 先后。
  /// 默认关闭：高峰期 apply_store_noop 可达数万次，刷屏拖主线程。
  static const bool enabled = false;

  static int _seq = 0;

  static int nextSeq() => ++_seq;

  static void log(
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) {
      return;
    }
    final seq = nextSeq();
    final ms = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('[ConvPinFlicker] #$seq t=$ms event=$event');
    final id = conversationID?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conv=$id');
    }
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    // ignore: avoid_print
    print(buffer.toString());
  }

  /// 列表前几项的简短顺序快照：`id:pin,id:pin,...`
  static String orderSnapshot(
    List<V2TimConversation> list, {
    int limit = 8,
  }) {
    if (list.isEmpty) {
      return '';
    }
    final take = list.length < limit ? list.length : limit;
    final parts = <String>[];
    for (var i = 0; i < take; i++) {
      final c = list[i];
      final shortId = c.conversationID.trim();
      final pin = c.isPinned == true ? '1' : '0';
      parts.add('$shortId:$pin');
    }
    if (list.length > take) {
      parts.add('…+${list.length - take}');
    }
    return parts.join(',');
  }

  /// 在 [list] 中找会话下标；找不到返回 -1。
  static int indexOfConversation(
    List<V2TimConversation> list,
    String conversationID,
  ) {
    final id = conversationID.trim();
    if (id.isEmpty) {
      return -1;
    }
    for (var i = 0; i < list.length; i++) {
      if (list[i].conversationID.trim() == id) {
        return i;
      }
    }
    return -1;
  }

  static String callerHint() {
    if (!enabled || !kDebugMode) {
      return '';
    }
    try {
      final lines = StackTrace.current.toString().split('\n');
      // 跳过本文件与当前帧，取第一条业务栈。
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }
        if (trimmed.contains('conversation_pin_flicker_log.dart')) {
          continue;
        }
        if (trimmed.contains('ConversationPinFlickerLog')) {
          continue;
        }
        return trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
      }
    } catch (_) {}
    return '';
  }
}

/// 置顶重排后的滚动策略。
enum ConversationPinScrollMode {
  /// 稳住视口邻居（项飞出视口时用；列表底部易被 max 夹死）。
  keepViewport,

  /// 跟随置顶项：保持其屏幕 Y，让用户看见它落入置顶区（往上滚，不受底部 max 限制）。
  followPinnedItem,

  /// 无需额外滚动（保留枚举兼容）。
  none,
}

/// 置顶重排后给列表滚动用的一次性提示。
class ConversationPinReorderScrollHint {
  const ConversationPinReorderScrollHint({
    required this.conversationID,
    required this.fromIndex,
    required this.toIndex,
    required this.isPinned,
    this.scrollMode = ConversationPinScrollMode.keepViewport,
  });

  final String conversationID;
  final int fromIndex;
  final int toIndex;
  final bool isPinned;
  final ConversationPinScrollMode scrollMode;

  bool get movedUp => toIndex >= 0 && fromIndex >= 0 && toIndex < fromIndex;

  bool get movedDown => toIndex >= 0 && fromIndex >= 0 && toIndex > fromIndex;
}
