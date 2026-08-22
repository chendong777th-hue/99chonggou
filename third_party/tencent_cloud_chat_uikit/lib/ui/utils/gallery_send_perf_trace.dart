import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';

/// 相册/相机选图发送性能追踪（Debug/Profile 输出 [gallery_send_perf] 日志）。
class GallerySendPerfTrace {
  GallerySendPerfTrace({required this.mode}) : id = (++_sequence).toString() {
    _watch.start();
    if (!kReleaseMode) {
      _timingsCallback = _onFrameTimings;
      SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
      _autoCloseTimer = Timer(const Duration(seconds: 20), close);
    }
  }

  static int _sequence = 0;

  /// 入口模式标识，例如 more_panel_custom / wide_mobile_album / camera。
  final String mode;
  final String id;
  final Stopwatch _watch = Stopwatch();
  TimingsCallback? _timingsCallback;
  Timer? _autoCloseTimer;
  int _asyncOperations = 0;
  bool _taskReturned = false;
  bool _closed = false;
  bool _firstThumbnailSettled = false;

  void _onFrameTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final totalMs = timing.totalSpan.inMicroseconds / 1000;
      if (totalMs <= 16.7) {
        continue;
      }
      log(
        'slow_frame',
        detail:
            'buildMs=${(timing.buildDuration.inMicroseconds / 1000).toStringAsFixed(1)} '
            'rasterMs=${(timing.rasterDuration.inMicroseconds / 1000).toStringAsFixed(1)} '
            'totalMs=${totalMs.toStringAsFixed(1)}',
      );
    }
  }

  void retainAsyncOperation() {
    _asyncOperations++;
  }

  void releaseAsyncOperation() {
    if (_asyncOperations > 0) {
      _asyncOperations--;
    }
    _closeIfComplete();
  }

  void markTaskReturned() {
    _taskReturned = true;
    _closeIfComplete();
  }

  void markFirstThumbnailReady({
    required int width,
    required int height,
  }) {
    if (_firstThumbnailSettled) {
      return;
    }
    _firstThumbnailSettled = true;
    log(
      'picker_first_thumbnail_ready',
      detail: 'width=$width height=$height',
    );
  }

  void markFirstThumbnailFailed(Object error) {
    if (_firstThumbnailSettled) {
      return;
    }
    _firstThumbnailSettled = true;
    log('picker_first_thumbnail_failed', detail: error.toString());
  }

  void _closeIfComplete() {
    if (_taskReturned && _asyncOperations == 0) {
      close();
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _autoCloseTimer?.cancel();
    final callback = _timingsCallback;
    if (callback != null) {
      SchedulerBinding.instance.removeTimingsCallback(callback);
    }
  }

  void log(
    String event, {
    int? index,
    int? count,
    int? bytes,
    String? detail,
  }) {
    if (kReleaseMode) {
      return;
    }
    final fields = <String>[
      '[gallery_send_perf]',
      'at=${DateTime.now().toIso8601String()}',
      'trace=$id',
      'mode=$mode',
      'elapsedMs=${_watch.elapsedMilliseconds}',
      'event=$event',
      if (index != null) 'index=$index',
      if (count != null) 'count=$count',
      if (bytes != null) 'bytes=$bytes',
      if (detail != null && detail.isNotEmpty) 'detail=$detail',
    ];
    final line = fields.join(' ');
    // uikitTrace 主要进入 IM SDK 日志文件，未必出现在 flutter run 控制台。
    // 诊断相册偶发空载时必须保留一条可直接采集的 Flutter 控制台日志。
    debugPrint(line);
    outputLogger.i(line);
  }
}
