import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

/// 全屏媒体预览调试日志。过滤关键字：`[MEDIA_PREVIEW]`
class MediaPreviewDebug {
  MediaPreviewDebug._();

  static const String tag = '[MEDIA_PREVIEW]';

  /// 诊断完成后关闭。需要复现预览滑动/转场问题时再临时改为 true。
  static const bool enabled = false;

  static void log(String event, [Map<String, Object?> extras = const {}]) {
    if (!enabled) {
      return;
    }
    final buffer = StringBuffer('$tag event=$event');
    extras.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    // ignore: avoid_print
    print(buffer.toString());
  }

  static String itemSummary(ChatMediaPreviewItem item) {
    final id = item.messageID ?? item.message.msgID ?? item.message.id?.toString();
    final shortId = (id == null || id.isEmpty)
        ? '-'
        : (id.length <= 12 ? id : '${id.substring(0, 6)}…${id.substring(id.length - 4)}');
    return '${item.type.name}:$shortId';
  }

  static String itemsSummary(List<ChatMediaPreviewItem> items) {
    if (items.isEmpty) {
      return '[]';
    }
    final parts = <String>[];
    for (var i = 0; i < items.length; i++) {
      parts.add('$i=${itemSummary(items[i])}');
    }
    return '[${parts.join(',')}]';
  }
}
