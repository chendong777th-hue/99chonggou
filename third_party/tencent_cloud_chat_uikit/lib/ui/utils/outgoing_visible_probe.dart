import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 复现「刚发出看得见、回列表再进没有」专用探针。
///
/// 控制台过滤：`[OutgoingVisible]`
/// 仅当会话 / sender / userID 含 [targetPeer] 时打印。
class OutgoingVisibleProbe {
  OutgoingVisibleProbe._();

  static const String targetPeer = 'rqwm8onw3j';
  static const String tag = '[OutgoingVisible]';
  /// SDK `getHistoryMessageList` 原页逐条。控制台过滤：`[SdkHistoryRaw]`
  static const String sdkRawTag = '[SdkHistoryRaw]';

  static String? lastConvID;
  static String? lastClientId;
  static String? lastMsgID;
  static String? lastText;
  static int? lastTs;
  static int? lastStatus;
  static int? lastElemType;

  static bool matches(String? raw) {
    final id = raw?.trim().toLowerCase() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return id.contains(targetPeer);
  }

  static bool matchesMessage(V2TimMessage? message) {
    if (message == null) {
      return false;
    }
    return matches(message.userID) ||
        matches(message.sender) ||
        matches(message.groupID);
  }

  static bool matchesAny(Iterable<String?> ids) {
    for (final id in ids) {
      if (matches(id)) {
        return true;
      }
    }
    return false;
  }

  static void rememberSent({
    required String conversationID,
    required V2TimMessage message,
  }) {
    lastConvID = conversationID.trim();
    lastClientId = message.id?.trim();
    lastMsgID = message.msgID?.trim();
    lastText = message.textElem?.text;
    lastTs = message.timestamp;
    lastStatus = message.status;
    lastElemType = message.elemType;
  }

  static void log(
    String event, {
    String? conversationID,
    V2TimMessage? message,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    final conv = conversationID?.trim() ?? lastConvID ?? '';
    if (!matches(conv) &&
        !matchesMessage(message) &&
        !matchesAny(extras.values.map((e) => e?.toString()))) {
      return;
    }
    final buffer = StringBuffer('$tag event=$event');
    if (conv.isNotEmpty) {
      buffer.write(' conv=$conv');
    }
    if (message != null) {
      buffer.write(' ${brief(message)}');
    }
    extras.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    debugPrint(buffer.toString());
  }

  /// 打印 SDK 本页原顺序、原字段。合并 / 过滤 / 排序之前调用。
  static void dumpSdkRawPage({
    required String source,
    String? userID,
    String? groupID,
    String? lastMsgID,
    required int askCount,
    required List<V2TimMessage> messages,
    bool? isFinished,
  }) {
    final conv = (userID ?? groupID ?? '').trim();
    if (!matches(conv) && !messages.any(matchesMessage)) {
      return;
    }
    debugPrint(
      '$sdkRawTag source=$source conv=$conv lastMsgID=${lastMsgID ?? ''} '
      'ask=$askCount got=${messages.length} isFinished=$isFinished '
      'order=sdk_as_returned',
    );
    for (var i = 0; i < messages.length; i++) {
      debugPrint('$sdkRawTag ${rawRow(i, messages[i])}');
    }
  }

  static String rawRow(int index, V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    return '#$index msgID=${message.msgID ?? ''} '
        'sender=${message.sender ?? ''} userID=${message.userID ?? ''} '
        'self=${message.isSelf} ts=$ts time=${_formatTs(ts)} '
        'seq=${message.seq ?? ''} status=${message.status} '
        'elem=${message.elemType} body=${_rawBody(message)}';
  }

  static String _formatTs(int ts) {
    if (ts <= 0) {
      return '-';
    }
    final ms = ts < 1000000000000 ? ts * 1000 : ts;
    return DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
  }

  static String _rawBody(V2TimMessage message) {
    switch (message.elemType) {
      case 1:
        return 'text=${_clip(message.textElem?.text ?? '', 240)}';
      case 2:
        return 'custom desc=${_clip(message.customElem?.desc ?? '', 80)} '
            'data=${_clip(message.customElem?.data ?? '', 200)}';
      case 3:
        return 'image path=${message.imageElem?.path ?? ''}';
      case 4:
        return 'sound dur=${message.soundElem?.duration ?? 0}';
      case 5:
        return 'video dur=${message.videoElem?.duration ?? 0}';
      case 6:
        return 'file ${message.fileElem?.fileName ?? ''}';
      case 7:
        return 'location ${message.locationElem?.desc ?? ''}';
      default:
        return 'elem=${message.elemType} '
            'cloud=${_clip(message.cloudCustomData ?? '', 80)}';
    }
  }

  static String _clip(String raw, int max) {
    final text = raw.replaceAll('\n', '\\n');
    if (text.length <= max) {
      return text;
    }
    return '${text.substring(0, max)}…';
  }

  static String brief(V2TimMessage message) {
    final text = message.textElem?.text ?? '';
    final clipped = text.length > 24 ? '${text.substring(0, 24)}…' : text;
    return 'msg{id=${message.id ?? ''} msgID=${message.msgID ?? ''} '
        'self=${message.isSelf} status=${message.status} '
        'elem=${message.elemType} ts=${message.timestamp ?? 0} '
        'seq=${message.seq ?? ''} text=$clipped}';
  }

  static Map<String, Object?> trackedInList(List<V2TimMessage>? messages) {
    if (messages == null || messages.isEmpty) {
      return <String, Object?>{
        'listCount': 0,
        'hasTrackedClientId': false,
        'hasTrackedMsgID': false,
        'newestSelf': '',
      };
    }
    final clientId = lastClientId ?? '';
    final msgID = lastMsgID ?? '';
    var hasClient = false;
    var hasMsg = false;
    V2TimMessage? newestSelf;
    for (final item in messages) {
      if (clientId.isNotEmpty && item.id?.trim() == clientId) {
        hasClient = true;
      }
      if (msgID.isNotEmpty && item.msgID?.trim() == msgID) {
        hasMsg = true;
      }
      if (item.isSelf == true &&
          (newestSelf == null ||
              (item.timestamp ?? 0) >= (newestSelf.timestamp ?? 0))) {
        newestSelf = item;
      }
    }
    return <String, Object?>{
      'listCount': messages.length,
      'hasTrackedClientId': hasClient,
      'hasTrackedMsgID': hasMsg,
      'trackedClientId': clientId,
      'trackedMsgID': msgID,
      'trackedText': lastText ?? '',
      'newestSelf': newestSelf == null ? '' : brief(newestSelf),
    };
  }
}
