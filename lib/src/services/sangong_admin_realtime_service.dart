import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_admin_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/sangong_game_http.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_realtime_state.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_sse_parser.dart';

/// 三公管理端实时状态：快照 + SSE 推送。
class SangongAdminRealtimeService {
  SangongAdminRealtimeService._();

  static final SangongAdminRealtimeService instance =
      SangongAdminRealtimeService._();

  static const List<Duration> _reconnectBackoff = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  final StreamController<SangongAdminRealtimeState> _statesController =
      StreamController<SangongAdminRealtimeState>.broadcast();

  SangongAdminRealtimeState? _latestState;
  int _listeners = 0;
  bool _starting = false;
  int _reconnectAttempt = 0;
  CancelToken? _streamCancelToken;
  StreamSubscription<List<int>>? _streamSubscription;
  Timer? _reconnectTimer;
  VoidCallback? _tenantListener;
  final SangongSseParser _sseParser = SangongSseParser();

  Stream<SangongAdminRealtimeState> get states => _statesController.stream;

  SangongAdminRealtimeState? get latestState => _latestState;

  bool get isActive => _listeners > 0;

  void acquire() {
    _listeners++;
    if (_listeners == 1) {
      _tenantListener ??= () {
        _onTenantChanged();
      };
      SangongGameHttp.tenantIdListenable.addListener(_tenantListener!);
      unawaited(_start());
    }
  }

  void release() {
    if (_listeners <= 0) {
      return;
    }
    _listeners--;
    if (_listeners <= 0) {
      _listeners = 0;
      if (_tenantListener != null) {
        SangongGameHttp.tenantIdListenable.removeListener(_tenantListener!);
      }
      _stop();
      _latestState = null;
    }
  }

  void _onTenantChanged() {
    if (_listeners <= 0) {
      return;
    }
    _stop();
    _latestState = null;
    _reconnectAttempt = 0;
    unawaited(_start());
  }

  Future<void> refreshSnapshot() async {
    if (!SangongGameHttp.canCallAdmin) {
      return;
    }
    try {
      final state = await SangongAdminApi.instance.fetchEventsSnapshot();
      _emit(state);
    } catch (error) {
      _log('snapshot refresh failed: $error');
    }
  }

  void _emit(SangongAdminRealtimeState state) {
    _latestState = state;
    if (!_statesController.isClosed) {
      _statesController.add(state);
    }
  }

  Future<void> _start() async {
    if (_starting || !SangongGameHttp.canCallAdmin) {
      return;
    }
    _starting = true;
    _reconnectTimer?.cancel();
    try {
      await refreshSnapshot();
      await _connectStream();
    } finally {
      _starting = false;
    }
  }

  void _stop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamCancelToken?.cancel('realtime stopped');
    _streamCancelToken = null;
    _sseParser.reset();
  }

  Future<void> _connectStream() async {
    if (_listeners <= 0 || !SangongGameHttp.canCallAdmin) {
      return;
    }
    await _streamSubscription?.cancel();
    _streamCancelToken?.cancel('reconnect');
    _streamCancelToken = CancelToken();
    final cancelToken = _streamCancelToken!;

    try {
      final response = await SangongGameHttp.adminClient.get<ResponseBody>(
        '/api/v1/admin/events/stream',
        options: Options(
          headers: const {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
          responseType: ResponseType.stream,
          receiveTimeout: 0,
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null || _listeners <= 0) {
        return;
      }
      _reconnectAttempt = 0;
      _streamSubscription = body.stream.listen(
        (chunk) {
          _sseParser.feed(utf8.decode(chunk), _onSseEvent);
        },
        onError: (Object error) {
          _log('stream error: $error');
          _scheduleReconnect();
        },
        onDone: () {
          _log('stream closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } on DioError catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      _log('stream connect failed: $error');
      _scheduleReconnect();
    } catch (error) {
      _log('stream connect failed: $error');
      _scheduleReconnect();
    }
  }

  void _onSseEvent(String event, String data) {
    if (event != 'state' && event != 'message') {
      return;
    }
    final state = SangongAdminRealtimeState.tryParseEventData(data);
    if (state != null) {
      _emit(state);
    }
  }

  void _scheduleReconnect() {
    if (_listeners <= 0 || _reconnectTimer != null) {
      return;
    }
    final index = _reconnectAttempt.clamp(0, _reconnectBackoff.length - 1);
    final delay = _reconnectBackoff[index];
    if (_reconnectAttempt < _reconnectBackoff.length - 1) {
      _reconnectAttempt++;
    }
    _reconnectTimer = Timer(delay, () {
      _reconnectTimer = null;
      if (_listeners > 0) {
        unawaited(_connectStream());
      }
    });
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[SangongRealtime] $message');
    }
  }
}
