import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 未读角标链路追踪；Debug 构建输出到控制台，Release 构建保持静默。
class ConversationUnreadTrace {
  ConversationUnreadTrace._();

  static const bool enabled = false;
  static const _tag = 'UnreadTrace';

  static void log(
    String event, {
    String? conversationID,
    int? unreadBefore,
    int? unreadAfter,
    Map<String, Object?> extras = const {},
  }) {
    if (!enabled && !kDebugMode) {
      return;
    }
    debugPrint(
      formatLineForTest(
        event,
        conversationID: conversationID,
        unreadBefore: unreadBefore,
        unreadAfter: unreadAfter,
        extras: extras,
      ),
    );
  }

  static void logConversations(
    String event, {
    required List<V2TimConversation> conversations,
    Map<String, Object?> extras = const {},
  }) {
    if (!enabled && !kDebugMode) {
      return;
    }
    final rows = conversations
        .map(
          (conversation) =>
              '${conversation.conversationID.trim()}:${conversation.unreadCount ?? 0}',
        )
        .where((entry) => entry.split(':').first.isNotEmpty)
        .join(',');
    debugPrint(
      formatLineForTest(
        event,
        extras: <String, Object?>{
          ...extras,
          'rows': rows.isEmpty ? '(none)' : rows,
        },
      ),
    );
  }

  @visibleForTesting
  static String formatLineForTest(
    String event, {
    String? conversationID,
    int? unreadBefore,
    int? unreadAfter,
    Map<String, Object?> extras = const {},
  }) {
    final buffer = StringBuffer('$_tag event=$event');
    final id = conversationID?.trim() ?? '';
    if (id.isNotEmpty) {
      buffer.write(' conv=$id');
    }
    if (unreadBefore != null) {
      buffer.write(' unreadBefore=$unreadBefore');
    }
    if (unreadAfter != null) {
      buffer.write(' unreadAfter=$unreadAfter');
    }
    for (final entry in extras.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      buffer.write(' ${entry.key}=$value');
    }
    return buffer.toString();
  }
}

/// 多选「标记已读」诊断的兼容入口；不向控制台输出。
class MarkSelectedReadLog {
  MarkSelectedReadLog._();

  static const bool enabled = false;
  static const int _idSampleLimit = 40;

  static void log(String message, [Map<String, Object?> extras = const {}]) {}

  static String summarizeIds(Iterable<String> ids,
      {int limit = _idSampleLimit}) {
    final list = ids.where((e) => e.trim().isNotEmpty).toList();
    if (list.isEmpty) {
      return '(none)';
    }
    if (list.length <= limit) {
      return list.join(',');
    }
    final head = list.take(limit).join(',');
    return '$head,...(+${list.length - limit})';
  }

  static String summarizeUnread(
    List<V2TimConversation> conversations, {
    int limit = _idSampleLimit,
  }) {
    final parts = <String>[];
    for (final conversation in conversations) {
      if (parts.length >= limit) {
        parts.add('...(+${conversations.length - limit})');
        break;
      }
      final id = conversation.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      parts.add('$id:${conversation.unreadCount ?? 0}');
    }
    return parts.isEmpty ? '(none)' : parts.join(',');
  }
}
