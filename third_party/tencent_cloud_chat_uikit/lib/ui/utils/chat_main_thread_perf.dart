import 'package:flutter/foundation.dart';

/// Lightweight, opt-in timings for chat-page frame pressure.
///
/// Production builds can never emit these lines. Enable [localProfileEnabled]
/// only while collecting a local profile build, then turn it back off.
class ChatMainThreadPerf {
  ChatMainThreadPerf._();

  static const String historyMergeMs = 'history_merge_ms';
  static const String setMessageListMs = 'set_message_list_ms';
  static const String groupMetadataApplyMs = 'group_metadata_apply_ms';
  static const String conversationReloadMs = 'conversation_reload_ms';
  static const String imageDecodeMs = 'image_decode_ms';
  static const String keyboardLayoutMs = 'keyboard_layout_ms';

  static const bool localProfileEnabled = false;

  @visibleForTesting
  static bool debugForceEnabled = false;

  @visibleForTesting
  static void Function(String line)? debugSink;

  static bool get isEnabled =>
      !kReleaseMode && (localProfileEnabled || debugForceEnabled);

  static String conversationTypeForId(String conversationId) {
    final value = conversationId.trim();
    return value.startsWith('group_') || value.startsWith('@TGS')
        ? 'group'
        : 'c2c';
  }

  static T measure<T>(
    String metric,
    T Function() operation, {
    int? count,
    String? source,
    String? conversationType,
  }) {
    if (!isEnabled) {
      return operation();
    }
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      _emit(metric, stopwatch.elapsedMicroseconds, count, source,
          conversationType);
    }
  }

  static Future<T> measureAsync<T>(
    String metric,
    Future<T> Function() operation, {
    int? count,
    String? source,
    String? conversationType,
  }) async {
    if (!isEnabled) {
      return operation();
    }
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      _emit(metric, stopwatch.elapsedMicroseconds, count, source,
          conversationType);
    }
  }

  static void _emit(
    String metric,
    int elapsedMicros,
    int? count,
    String? source,
    String? conversationType,
  ) {
    final fields = <String>[
      '[ChatMainPerf]',
      'metric=${_safeLabel(metric)}',
      'ms=${(elapsedMicros / 1000).toStringAsFixed(3)}',
      if (count != null) 'count=$count',
      if (source != null) 'source=${_safeLabel(source)}',
      if (conversationType != null) 'convType=${_safeLabel(conversationType)}',
    ];
    final line = fields.join(' ');
    final sink = debugSink;
    if (sink != null) {
      sink(line);
    } else {
      debugPrint(line);
    }
  }

  static String _safeLabel(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return sanitized.length <= 32 ? sanitized : sanitized.substring(0, 32);
  }
}
