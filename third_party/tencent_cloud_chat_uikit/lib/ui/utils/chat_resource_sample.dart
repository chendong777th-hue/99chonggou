import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';

/// 聊天资源生命周期实验采样。过滤：`[CHAT_RESOURCE]`。
///
/// 仅在节点采样（initial / after_100|500|1000 / bottom / leave / leave_15s），
/// 禁止挂在每个 ScrollUpdate 上扫盘。发布版用 [print] 进控制台。
class ChatResourceSample {
  ChatResourceSample._();

  /// 实验包 true；测完改回 false。
  static const bool enabled = false;

  static const Duration leaveGrace = Duration(seconds: 15);

  static String _chatId = '';
  static int _openSeq = 0;
  static final Set<String> _firedStages = <String>{};
  static Timer? _leave15Timer;
  static Future<void>? _sampleInFlight;

  static void resetForChatOpen(String? conversationID) {
    if (!enabled) {
      return;
    }
    _leave15Timer?.cancel();
    _leave15Timer = null;
    _chatId = conversationID?.trim() ?? '';
    _openSeq++;
    _firedStages.clear();
    unawaited(sample(stage: 'initial'));
  }

  /// 上翻后 rawMessageCount 变化时调用。
  /// Window 化后通常平台在 ~120–160，故增加 after_120 / after_160；
  /// after_500/1000 在窗口生效后可能永不触发（对比基线仍保留）。
  static void onRawMessageCount(int rawMessageCount) {
    if (!enabled) {
      return;
    }
    if (rawMessageCount >= 100) {
      unawaited(sample(stage: 'after_100', rawMessageCount: rawMessageCount));
    }
    if (rawMessageCount >= 120) {
      unawaited(sample(stage: 'after_120', rawMessageCount: rawMessageCount));
    }
    if (rawMessageCount >= 160) {
      unawaited(sample(stage: 'after_160', rawMessageCount: rawMessageCount));
    }
    if (rawMessageCount >= 500) {
      unawaited(sample(stage: 'after_500', rawMessageCount: rawMessageCount));
    }
    if (rawMessageCount >= 1000) {
      unawaited(sample(stage: 'after_1000', rawMessageCount: rawMessageCount));
    }
  }

  static void onBottom({int? rawMessageCount}) {
    if (!enabled) {
      return;
    }
    unawaited(sample(stage: 'bottom', rawMessageCount: rawMessageCount));
  }

  static void onLeave({int? rawMessageCount}) {
    if (!enabled) {
      return;
    }
    unawaited(sample(stage: 'leave', rawMessageCount: rawMessageCount));
    _leave15Timer?.cancel();
    final chatId = _chatId;
    final openSeq = _openSeq;
    _leave15Timer = Timer(leaveGrace, () {
      _leave15Timer = null;
      if (!enabled) {
        return;
      }
      // 15s 内若又进了别的会话，仍用离开时的 chatId/openSeq 打 leave_15s。
      unawaited(
        sample(
          stage: 'leave_15s',
          rawMessageCount: rawMessageCount,
          chatIdOverride: chatId,
          openSeqOverride: openSeq,
        ),
      );
    });
  }

  static Future<void> sample({
    required String stage,
    int? rawMessageCount,
    String? chatIdOverride,
    int? openSeqOverride,
  }) async {
    if (!enabled) {
      return;
    }
    final stageKey = stage.trim();
    if (stageKey.isEmpty || !_firedStages.add(stageKey)) {
      return;
    }

    // 串行采样，避免节点上并发全盘 sum。
    while (_sampleInFlight != null) {
      try {
        await _sampleInFlight;
      } catch (_) {}
    }
    final run = _runSample(
      stage: stageKey,
      rawMessageCount: rawMessageCount,
      chatIdOverride: chatIdOverride,
      openSeqOverride: openSeqOverride,
    );
    _sampleInFlight = run;
    try {
      await run;
    } finally {
      if (identical(_sampleInFlight, run)) {
        _sampleInFlight = null;
      }
    }
  }

  static Future<void> _runSample({
    required String stage,
    int? rawMessageCount,
    String? chatIdOverride,
    int? openSeqOverride,
  }) async {
    final cache = PaintingBinding.instance.imageCache;
    final mediaRootBytes = await _sumMediaRootBytes();
    final chatId = (chatIdOverride ?? _chatId).trim();
    final openSeq = openSeqOverride ?? _openSeq;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('[CHAT_RESOURCE] event=chat_resource_sample')
      ..write(' stage=$stage')
      ..write(' chatId=${chatId.isEmpty ? '-' : chatId}')
      ..write(' openSeq=$openSeq')
      ..write(' rawMessageCount=${rawMessageCount ?? -1}')
      ..write(' imageCacheCount=${cache.currentSize}')
      ..write(' imageCacheBytes=${cache.currentSizeBytes}')
      ..write(' mediaRootBytes=${mediaRootBytes ?? -1}')
      ..write(' ts=$ts');
    // ignore: avoid_print
    print(buffer.toString());
  }

  /// 与设置页 mediaRoot 语义对齐：优先 `{appFileDir}/{sdkAppId}/{user}`。
  static Future<int?> _sumMediaRootBytes() async {
    try {
      final root = CommonUtils.appFileDir;
      final sdkAppId = CommonUtils.getSDKAppID();
      final loginUser = CommonUtils.getLoginUser();
      var target = root;
      if (sdkAppId != null && loginUser.isNotEmpty) {
        final scoped = Directory('${root.path}${Platform.pathSeparator}'
            '$sdkAppId${Platform.pathSeparator}$loginUser');
        if (await scoped.exists()) {
          target = scoped;
        }
      }
      return _directorySize(target);
    } catch (_) {
      return null;
    }
  }

  static Future<int> _directorySize(Directory dir) async {
    if (!await dir.exists()) {
      return 0;
    }
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }
}
