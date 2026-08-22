import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/api_node_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_connection.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_endpoint.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/presence_last_seen_codec.dart';

typedef FriendRealtimeEventHandler = void Function(FriendRealtimeEvent event);
typedef FriendRealtimeAuthOkHandler = void Function();
typedef FriendRealtimeReadyHandler = void Function(bool ready);

class FriendRealtimeService {
  FriendRealtimeService._();

  static final FriendRealtimeService instance = FriendRealtimeService._();

  FriendRealtimeEventHandler? onEvent;
  FriendRealtimeAuthOkHandler? onAuthOk;
  final List<FriendRealtimeAuthOkHandler> _authOkListeners =
      <FriendRealtimeAuthOkHandler>[];
  final List<FriendRealtimeReadyHandler> _readyListeners =
      <FriendRealtimeReadyHandler>[];

  FriendRealtimeConnection? _connection;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _running = false;
  bool _authFailed = false;
  bool _authOk = false;
  bool _lastEmittedReady = false;
  int _reconnectAttempt = 0;
  int _connectGeneration = 0;
  int _lastSeenSeq = 0;
  final Map<String, Completer<PresenceLastSeenBatch>> _lastSeenWaiters =
      <String, Completer<PresenceLastSeenBatch>>{};
  final Map<String, List<String>> _lastSeenUserIds = <String, List<String>>{};
  final Map<String, Timer> _lastSeenTimeouts = <String, Timer>{};
  final List<_QueuedPresenceLastSeen> _lastSeenQueue =
      <_QueuedPresenceLastSeen>[];

  static const Duration _lastSeenTimeout = Duration(seconds: 8);
  static const Duration _internalRetryDelay = Duration(milliseconds: 300);

  /// TCP 已认证且连接仍在；好友申请轮询在此为 true 时应跳过。
  bool get isRealtimeReady =>
      _running && _authOk && !_authFailed && _connection != null;

  void addAuthOkListener(FriendRealtimeAuthOkHandler listener) {
    if (!_authOkListeners.contains(listener)) {
      _authOkListeners.add(listener);
    }
  }

  void removeAuthOkListener(FriendRealtimeAuthOkHandler listener) {
    _authOkListeners.remove(listener);
  }

  void addReadyListener(FriendRealtimeReadyHandler listener) {
    if (!_readyListeners.contains(listener)) {
      _readyListeners.add(listener);
    }
  }

  void removeReadyListener(FriendRealtimeReadyHandler listener) {
    _readyListeners.remove(listener);
  }

  void _emitAuthOk() {
    onAuthOk?.call();
    for (final listener in List<FriendRealtimeAuthOkHandler>.from(
      _authOkListeners,
    )) {
      listener();
    }
  }

  void _emitReadyIfChanged() {
    final ready = isRealtimeReady;
    if (ready == _lastEmittedReady) {
      return;
    }
    _lastEmittedReady = ready;
    for (final listener in List<FriendRealtimeReadyHandler>.from(
      _readyListeners,
    )) {
      listener(ready);
    }
  }

  // ignore: avoid_print
  static void _log(String message) {
    // Verbose realtime tracing disabled.
  }

  void start() {
    final wasRunning = _running;
    _running = true;
    if (!wasRunning) {
      _reconnectAttempt = 0;
    }
    _log('start wasRunning=$wasRunning authFailed=$_authFailed');
    unawaited(ensureConnected(force: true));
  }

  Future<void> ensureConnected({bool force = false}) async {
    if (!_running) {
      _log('ensureConnected skipped: not running');
      return;
    }
    if (_authFailed) {
      _log('ensureConnected skipped authFailed=$_authFailed');
      return;
    }
    if (!force && _connection != null) {
      return;
    }
    if (force) {
      _authFailed = false;
    }
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _connect();
  }

  void onAppLifecycleChanged(AppLifecycleState state) {
    if (!_running) {
      return;
    }
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _log('background: keep realtime tcp connected');
        unawaited(ensureConnected());
        return;
      case AppLifecycleState.resumed:
        _log('foreground: ensure realtime tcp connected');
        unawaited(ensureConnected(force: _connection == null));
        return;
      default:
        return;
    }
  }

  Future<void> stop() async {
    _log('stop: disconnect realtime tcp');
    _running = false;
    _authFailed = false;
    _authOk = false;
    _reconnectAttempt = 0;
    _connectGeneration++;
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _failAllLastSeen(PresenceLastSeenFailCode.disconnected);
    final connection = _connection;
    _connection = null;
    _emitReadyIfChanged();
    if (connection != null) {
      await connection.close();
    }
    _log('stop: realtime tcp disconnected');
  }

  Future<void> _connect() async {
    if (!_running || _authFailed) {
      return;
    }
    _authOk = false;
    _emitReadyIfChanged();
    final connectGeneration = ++_connectGeneration;
    final token = ApiClient.instance.token;
    if (!ApiClient.isValidJwt(token)) {
      _scheduleReconnect();
      return;
    }

    final tcpBase = ApiNodeService.instance.isHydrated
        ? ApiNodeService.instance.currentRealtimeTcpBase
        : IMDemoConfig.realtimeTcpBase;
    final endpoint = FriendRealtimeEndpoint.parse(tcpBase);
    if (endpoint == null) {
      _scheduleReconnect();
      return;
    }

    await _connection?.close();
    final connection = FriendRealtimeConnection(
      onLine: _handleLine,
      onDisconnected: _handleDisconnected,
    );
    _connection = connection;

    try {
      _log(
        'connecting to ${endpoint.host}:${endpoint.port} '
        'tls=${endpoint.useTls}',
      );
      await connection.connect(
        host: endpoint.host,
        port: endpoint.port,
        useTls: endpoint.useTls,
      );
      if (!_running ||
          _authFailed ||
          connectGeneration != _connectGeneration) {
        await connection.close();
        if (identical(_connection, connection)) {
          _connection = null;
        }
        return;
      }
      await ApiClient.instance.ensureDeviceIdReady();
      await connection.send(<String, dynamic>{
        'type': 'auth',
        'token': token,
        'deviceId': ApiClient.instance.deviceId,
      });
      if (!_running ||
          _authFailed ||
          connectGeneration != _connectGeneration) {
        await connection.close();
        if (identical(_connection, connection)) {
          _connection = null;
        }
        return;
      }
      _log('connected, auth sent deviceId=${ApiClient.instance.deviceId}');
    } catch (e, st) {
      _log('connect failed: $e');
      _log('connect failed stack: $st');
      await connection.close();
      if (identical(_connection, connection)) {
        _connection = null;
      }
      if (_running && connectGeneration == _connectGeneration) {
        _scheduleReconnect();
      }
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    unawaited(_sendPing());
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_sendPing());
    });
  }

  Future<void> _sendPing() async {
    if (!isRealtimeReady) {
      return;
    }
    try {
      await ApiClient.instance.ensureDeviceIdReady();
      await _connection?.send(
        PresenceLastSeenCodec.pingFrame(ApiClient.instance.deviceId),
      );
    } catch (_) {}
  }

  void _handleLine(String line) {
    Map<String, dynamic> map;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map) {
        return;
      }
      map = Map<String, dynamic>.from(decoded);
    } catch (e) {
      _log('invalid frame: $line');
      return;
    }

    _log('recv: $line');

    final type = map['type']?.toString().trim() ?? '';
    final eventName = map['event']?.toString().trim() ?? '';

    switch (type) {
      case 'auth_ok':
        _reconnectAttempt = 0;
        _authOk = true;
        _log('auth ok');
        _startPing();
        _emitReadyIfChanged();
        _emitAuthOk();
        return;
      case 'auth_fail':
        _authFailed = true;
        _authOk = false;
        _pingTimer?.cancel();
        _pingTimer = null;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _failAllLastSeen(PresenceLastSeenFailCode.disconnected);
        unawaited(_connection?.close());
        _connection = null;
        _emitReadyIfChanged();
        _log('auth failed: $map');
        return;
      case 'pong':
        return;
      case 'presence_last_seen_ok':
        _completeLastSeenOk(map);
        return;
      case 'presence_last_seen_fail':
        unawaited(_completeLastSeenFail(map));
        return;
      case 'event':
        if (eventName.isNotEmpty) {
          _log('event frame: $eventName');
          onEvent?.call(FriendRealtimeEvent.fromJson(map));
        }
        return;
      case 'error':
        _log('error frame: $map');
        return;
    }

    if (_isRealtimeEventName(eventName)) {
      _log('direct event: $eventName');
      onEvent?.call(FriendRealtimeEvent.fromJson(map));
      return;
    }
    if (_isRealtimeEventName(type)) {
      _log('typed event: $type');
      onEvent?.call(FriendRealtimeEvent.fromJson(<String, dynamic>{
        ...map,
        'event': type,
      }));
      return;
    }

    if (type.isNotEmpty) {
      _log('unknown frame type: $type');
    }
  }

  bool _isRealtimeEventName(String name) {
    switch (name) {
      case 'friend_request_received':
      case 'friend_request_accepted':
      case 'friend_request_rejected':
      case 'friend_request_auto_accepted':
      case 'friend_restored':
      case 'friend_list_changed':
      case 'group_changed':
      case 'call_recent_changed':
      case 'presence_changed':
      case 'red_packet_changed':
        return true;
      case 'moment_changed':
        return true;
      case 'conversation_archive_changed':
        return true;
      case 'conversation_folder_changed':
        return true;
      case 'conversation_pin_changed':
        return true;
      default:
        return false;
    }
  }

  void _handleDisconnected() {
    if (!_running || _authFailed) {
      return;
    }
    _authOk = false;
    _pingTimer?.cancel();
    _pingTimer = null;
    _failAllLastSeen(PresenceLastSeenFailCode.disconnected);
    if (!identical(_connection, null)) {
      _connection = null;
    }
    _emitReadyIfChanged();
    _scheduleReconnect();
  }

  /// 冷启动 / 视口补拉：TCP 主路径；未就绪时由调用方回退 HTTP。
  Future<PresenceLastSeenBatch> fetchPresenceLastSeen(
    List<String> userIds,
  ) async {
    final ids = PresenceLastSeenCodec.normalizeUserIds(userIds);
    if (ids.isEmpty) {
      return const PresenceLastSeenBatch(
        lastSeen: {},
        lastActiveVisibility: {},
      );
    }
    if (!isRealtimeReady) {
      throw const PresenceLastSeenTcpException(
        PresenceLastSeenFailCode.notConnected,
      );
    }
    final chunks = PresenceLastSeenCodec.chunkUserIds(ids);
    if (chunks.length == 1) {
      return _fetchPresenceLastSeenChunk(chunks.first);
    }
    final lastSeen = <String, int>{};
    final visibility = <String, String>{};
    for (final chunk in chunks) {
      final part = await _fetchPresenceLastSeenChunk(chunk);
      lastSeen.addAll(part.lastSeen);
      visibility.addAll(part.lastActiveVisibility);
    }
    return PresenceLastSeenBatch(
      lastSeen: lastSeen,
      lastActiveVisibility: visibility,
    );
  }

  Future<PresenceLastSeenBatch> _fetchPresenceLastSeenChunk(
    List<String> userIds, {
    int attempt = 0,
  }) async {
    try {
      return await _enqueueLastSeen(userIds);
    } on PresenceLastSeenTcpException catch (e) {
      if (e.code == PresenceLastSeenFailCode.internal && attempt < 1) {
        await Future<void>.delayed(_internalRetryDelay);
        return _fetchPresenceLastSeenChunk(userIds, attempt: attempt + 1);
      }
      rethrow;
    }
  }

  Future<PresenceLastSeenBatch> _enqueueLastSeen(List<String> userIds) {
    final completer = Completer<PresenceLastSeenBatch>();
    final queued = _QueuedPresenceLastSeen(
      userIds: userIds,
      completer: completer,
    );
    _lastSeenQueue.add(queued);
    _drainLastSeenQueue();
    return completer.future;
  }

  String _nextLastSeenRequestId() {
    _lastSeenSeq++;
    return 'pls-$_lastSeenSeq-${DateTime.now().microsecondsSinceEpoch}';
  }

  void _drainLastSeenQueue() {
    while (_lastSeenWaiters.length < PresenceLastSeenCodec.maxInflight &&
        _lastSeenQueue.isNotEmpty) {
      if (!isRealtimeReady) {
        _failAllLastSeen(PresenceLastSeenFailCode.notConnected);
        return;
      }
      final next = _lastSeenQueue.removeAt(0);
      if (next.completer.isCompleted) {
        continue;
      }
      final requestId = _nextLastSeenRequestId();
      _lastSeenWaiters[requestId] = next.completer;
      _lastSeenUserIds[requestId] = next.userIds;
      _lastSeenTimeouts[requestId]?.cancel();
      _lastSeenTimeouts[requestId] = Timer(_lastSeenTimeout, () {
        _finishLastSeen(
          requestId,
          error: PresenceLastSeenTcpException(
            PresenceLastSeenFailCode.timeout,
            requestId: requestId,
          ),
        );
      });
      unawaited(() async {
        try {
          await _connection?.send(
            PresenceLastSeenCodec.lastSeenRequestFrame(
              requestId: requestId,
              userIds: next.userIds,
            ),
          );
        } catch (_) {
          _finishLastSeen(
            requestId,
            error: PresenceLastSeenTcpException(
              PresenceLastSeenFailCode.disconnected,
              requestId: requestId,
            ),
          );
        }
      }());
    }
  }

  void _completeLastSeenOk(Map<String, dynamic> map) {
    final requestId = PresenceLastSeenCodec.requestIdOf(map);
    if (requestId == null) {
      return;
    }
    _finishLastSeen(
      requestId,
      batch: PresenceLastSeenCodec.parseBatch(map),
    );
  }

  Future<void> _completeLastSeenFail(Map<String, dynamic> map) async {
    final requestId = PresenceLastSeenCodec.requestIdOf(map);
    final code = PresenceLastSeenCodec.failCodeOf(map) ??
        PresenceLastSeenFailCode.internal;
    if (requestId == null) {
      return;
    }
    if (code == PresenceLastSeenFailCode.tooManyInflight) {
      final waiter = _lastSeenWaiters.remove(requestId);
      final userIds = _lastSeenUserIds.remove(requestId) ?? const <String>[];
      _lastSeenTimeouts.remove(requestId)?.cancel();
      if (waiter != null && !waiter.isCompleted && userIds.isNotEmpty) {
        _lastSeenQueue.insert(
          0,
          _QueuedPresenceLastSeen(
            userIds: userIds,
            completer: waiter,
          ),
        );
      } else if (waiter != null && !waiter.isCompleted) {
        waiter.completeError(
          PresenceLastSeenTcpException(
            PresenceLastSeenFailCode.tooManyInflight,
            requestId: requestId,
          ),
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      _drainLastSeenQueue();
      return;
    }
    _finishLastSeen(
      requestId,
      error: PresenceLastSeenTcpException(code, requestId: requestId),
    );
  }

  void _finishLastSeen(
    String requestId, {
    PresenceLastSeenBatch? batch,
    PresenceLastSeenTcpException? error,
  }) {
    _lastSeenTimeouts.remove(requestId)?.cancel();
    _lastSeenUserIds.remove(requestId);
    final waiter = _lastSeenWaiters.remove(requestId);
    if (waiter == null || waiter.isCompleted) {
      _drainLastSeenQueue();
      return;
    }
    if (batch != null) {
      waiter.complete(batch);
    } else {
      waiter.completeError(
        error ??
            PresenceLastSeenTcpException(
              PresenceLastSeenFailCode.internal,
              requestId: requestId,
            ),
      );
    }
    _drainLastSeenQueue();
  }

  void _failAllLastSeen(String code) {
    final queued = List<_QueuedPresenceLastSeen>.from(_lastSeenQueue);
    _lastSeenQueue.clear();
    final waiters = Map<String, Completer<PresenceLastSeenBatch>>.from(
      _lastSeenWaiters,
    );
    _lastSeenWaiters.clear();
    _lastSeenUserIds.clear();
    for (final timer in _lastSeenTimeouts.values) {
      timer.cancel();
    }
    _lastSeenTimeouts.clear();
    final error = PresenceLastSeenTcpException(code);
    for (final item in queued) {
      if (!item.completer.isCompleted) {
        item.completer.completeError(error);
      }
    }
    for (final waiter in waiters.values) {
      if (!waiter.isCompleted) {
        waiter.completeError(error);
      }
    }
  }

  void _scheduleReconnect() {
    if (!_running || _authFailed) {
      return;
    }
    _reconnectTimer?.cancel();
    final seconds = _reconnectDelaySeconds(_reconnectAttempt);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      unawaited(_connect());
    });
  }

  int _reconnectDelaySeconds(int attempt) {
    if (attempt <= 0) {
      return 1;
    }
    final delay = 1 << attempt.clamp(0, 6);
    return delay > 60 ? 60 : delay;
  }
}

class _QueuedPresenceLastSeen {
  _QueuedPresenceLastSeen({
    required this.userIds,
    required this.completer,
  });

  final List<String> userIds;
  final Completer<PresenceLastSeenBatch> completer;
}
