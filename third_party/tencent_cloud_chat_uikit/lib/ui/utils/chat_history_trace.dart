import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// Chat history pagination / 首屏源追溯。过滤关键字：`[ChatHistory]`。
class ChatHistoryTrace {
  ChatHistoryTrace._();

  /// 诊断完成后关闭。需要追溯分页/首屏源时再临时改为 true。
  static const bool enabled = false;

  /// SDK uikitTrace 仅 debug，避免 release 滚动开销。
  static const bool sdkTraceEnabled = false;

  static void log(
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    if (!enabled) {
      return;
    }
    final buffer = StringBuffer('[ChatHistory] event=$event');
    final conv = conversationID?.trim() ?? '';
    if (conv.isNotEmpty) {
      buffer.write(' conv=$conv');
    }
    extras.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    final text = buffer.toString();
    // ignore: avoid_print
    print(text);
    if (sdkTraceEnabled && !PlatformUtils().isWeb) {
      TencentImSDKPlugin.v2TIMManager.uikitTrace(trace: text);
    }
  }

  /// 首/尾消息摘要：count / msgId / ts / seq，用于对比 Peek 与聊天页窗口。
  static Map<String, Object?> windowSummary(
    List<V2TimMessage>? messages, {
    String prefix = 'win',
  }) {
    if (messages == null || messages.isEmpty) {
      return <String, Object?>{
        '${prefix}Count': 0,
      };
    }
    // 列表约定：通常 newest-first；取首尾各一条。
    final first = messages.first;
    final last = messages.last;
    final oldest = _olderOf(first, last);
    final newest = identical(oldest, first) ? last : first;
    return <String, Object?>{
      '${prefix}Count': messages.length,
      '${prefix}NewestId': _shortMsgId(newest.msgID),
      '${prefix}NewestTs': newest.timestamp ?? 0,
      '${prefix}NewestSeq': newest.seq ?? '',
      '${prefix}OldestId': _shortMsgId(oldest.msgID),
      '${prefix}OldestTs': oldest.timestamp ?? 0,
      '${prefix}OldestSeq': oldest.seq ?? '',
      '${prefix}ImageHttp': _countImageHttp(messages),
      '${prefix}ArchiveMarked': _countArchiveMarked(messages),
    };
  }

  static V2TimMessage _olderOf(V2TimMessage a, V2TimMessage b) {
    final at = a.timestamp ?? 0;
    final bt = b.timestamp ?? 0;
    if (at != bt) {
      return at <= bt ? a : b;
    }
    final as = int.tryParse(a.seq?.toString() ?? '') ?? 0;
    final bs = int.tryParse(b.seq?.toString() ?? '') ?? 0;
    return as <= bs ? a : b;
  }

  static String _shortMsgId(String? msgID) {
    final id = msgID?.trim() ?? '';
    if (id.length <= 28) {
      return id;
    }
    return '${id.substring(0, 12)}…${id.substring(id.length - 8)}';
  }

  static int _countImageHttp(List<V2TimMessage> messages) {
    var n = 0;
    for (final m in messages) {
      if (m.elemType != 3) {
        continue;
      }
      final list = m.imageElem?.imageList;
      if (list == null) {
        continue;
      }
      for (final img in list) {
        final url = img?.url?.trim() ?? '';
        if (url.startsWith('http://') || url.startsWith('https://')) {
          n++;
          break;
        }
      }
    }
    return n;
  }

  static int _countArchiveMarked(List<V2TimMessage> messages) {
    var n = 0;
    for (final m in messages) {
      final raw = m.localCustomData?.trim() ?? '';
      if (raw.contains('archiveHistory')) {
        n++;
      }
    }
    return n;
  }
}
