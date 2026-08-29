import 'dart:async';

import 'package:flutter/scheduler.dart';

import 'chat_main_thread_perf.dart';

typedef ChatImageDecodeAdmit = void Function();

class _DecodeRequest {
  _DecodeRequest({
    required this.key,
    required this.visible,
    required this.onAdmit,
  });

  final String key;
  bool visible;
  ChatImageDecodeAdmit onAdmit;
}

/// Admits at most one new chat image decode per Flutter frame.
class ChatImageDecodeAdmission {
  ChatImageDecodeAdmission._();

  static final ChatImageDecodeAdmission instance = ChatImageDecodeAdmission._();

  final List<_DecodeRequest> _requests = <_DecodeRequest>[];
  bool _frameScheduled = false;

  void request({
    required String key,
    required bool visible,
    required ChatImageDecodeAdmit onAdmit,
  }) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      ChatMainThreadPerf.increment('image_decode_admit_immediate');
      scheduleMicrotask(onAdmit);
      return;
    }
    for (final request in _requests) {
      if (request.key == normalized) {
        request.visible = request.visible || visible;
        request.onAdmit = onAdmit;
        ChatMainThreadPerf.increment('image_decode_request_coalesced');
        _scheduleFrame();
        return;
      }
    }
    _requests.add(_DecodeRequest(
      key: normalized,
      visible: visible,
      onAdmit: onAdmit,
    ));
    ChatMainThreadPerf.increment('image_decode_request_queued');
    _scheduleFrame();
  }

  void cancel(String key) {
    final normalized = key.trim();
    _requests.removeWhere((request) => request.key == normalized);
  }

  void _scheduleFrame() {
    if (_frameScheduled || _requests.isEmpty) {
      return;
    }
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrame();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (_requests.isEmpty) {
        return;
      }
      var index = _requests.indexWhere((request) => request.visible);
      if (index < 0) {
        index = 0;
      }
      final request = _requests.removeAt(index);
      ChatMainThreadPerf.increment(
        request.visible
            ? 'image_decode_admitted_visible'
            : 'image_decode_admitted_offscreen',
      );
      request.onAdmit();
      _scheduleFrame();
    });
  }

  void resetForTesting() {
    _requests.clear();
    _frameScheduled = false;
  }
}
