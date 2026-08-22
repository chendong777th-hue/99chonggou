import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/dio_factory.dart';

enum ApiNodeProbeStatus {
  unknown,
  normal,
  abnormal,
}

class ApiNodeDefinition {
  const ApiNodeDefinition({
    required this.id,
    required this.name,
    required this.apiBaseUrl,
    required this.realtimeTcpBase,
  });

  final String id;
  final String name;
  final String apiBaseUrl;
  final String realtimeTcpBase;
}

class ApiNodeProbeResult {
  const ApiNodeProbeResult({
    required this.status,
    this.latencyMs,
  });

  final ApiNodeProbeStatus status;
  final int? latencyMs;
}

/// 业务 API / 实时 TCP 节点选择与测速。
class ApiNodeService extends ChangeNotifier {
  ApiNodeService._();

  static final ApiNodeService instance = ApiNodeService._();

  static const String _prefsSelectedNodeId = 'api_node_selected_id';
  static const String _prefsLastProbeAtMs = 'api_node_last_probe_at_ms';
  static const String _prefsProbePrefix = 'api_node_probe_';
  static const String _prefsFirstAutoProbeDone = 'api_node_first_auto_probe_done';

  /// 连续传输失败达到该次数后，自动切换到其它正常节点。
  static const int failureSwitchThreshold = 3;

  /// 当前仅启用单一节点（CN）；不再提供 OS 节点切换。
  static const List<ApiNodeDefinition> catalog = <ApiNodeDefinition>[
    ApiNodeDefinition(
      id: 'cn',
      name: '节点02(CN)',
      apiBaseUrl: 'https://api99chat.99chat.vip',
      realtimeTcpBase: 'https://tcp.99chat.vip:8082',
    ),
  ];

  static const String defaultNodeId = 'cn';

  String _selectedNodeId = defaultNodeId;
  DateTime? _lastProbeAt;
  final Map<String, ApiNodeProbeResult> _probeById =
      <String, ApiNodeProbeResult>{};
  bool _hydrated = false;
  bool _probing = false;
  int _consecutiveFailures = 0;
  bool _failoverInFlight = false;

  bool get isHydrated => _hydrated;
  bool get isProbing => _probing;
  String get selectedNodeId => _selectedNodeId;
  DateTime? get lastProbeAt => _lastProbeAt;
  int get consecutiveFailures => _consecutiveFailures;

  ApiNodeDefinition get currentNode => nodeById(_selectedNodeId);

  String get currentApiBaseUrl => currentNode.apiBaseUrl;

  String get currentRealtimeTcpBase => currentNode.realtimeTcpBase;

  ApiNodeDefinition nodeById(String id) {
    for (final node in catalog) {
      if (node.id == id) {
        return node;
      }
    }
    return catalog.firstWhere(
      (n) => n.id == defaultNodeId,
      orElse: () => catalog.first,
    );
  }

  ApiNodeProbeResult? probeOf(String nodeId) => _probeById[nodeId];

  /// 从测速结果中挑选延迟最低的「正常」节点；[excludeId] 用于故障切换时排除当前节点。
  static ApiNodeDefinition? pickFastestNormal({
    required Map<String, ApiNodeProbeResult> probes,
    String? excludeId,
  }) {
    ApiNodeDefinition? best;
    int? bestMs;
    for (final node in catalog) {
      if (excludeId != null && node.id == excludeId) {
        continue;
      }
      final probe = probes[node.id];
      if (probe == null || probe.status != ApiNodeProbeStatus.normal) {
        continue;
      }
      final ms = probe.latencyMs;
      if (ms == null) {
        continue;
      }
      if (best == null || ms < bestMs!) {
        best = node;
        bestMs = ms;
      }
    }
    return best;
  }

  /// 启动早期调用：恢复选中节点；仅首次安装测速并选最快；挂载失败计数回调。
  Future<void> hydrate() async {
    if (_hydrated) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_prefsSelectedNodeId)?.trim();
    final firstAutoDone = prefs.getBool(_prefsFirstAutoProbeDone) ?? false;

    final probeAtMs = prefs.getInt(_prefsLastProbeAtMs);
    if (probeAtMs != null && probeAtMs > 0) {
      _lastProbeAt = DateTime.fromMillisecondsSinceEpoch(probeAtMs);
    }
    for (final node in catalog) {
      final raw = prefs.getString('$_prefsProbePrefix${node.id}');
      final parsed = _decodeProbe(raw);
      if (parsed != null) {
        _probeById[node.id] = parsed;
      }
    }

    // 仅首次（从未写过选中节点且未做过自动测速）：测速后选最快正常节点。
    if (!firstAutoDone && (savedId == null || savedId.isEmpty)) {
      _selectedNodeId = defaultNodeId;
      ApiClient.applyRuntimeBaseUrl(currentApiBaseUrl);
      try {
        await probeAll();
        final best = pickFastestNormal(probes: _probeById);
        if (best != null) {
          _selectedNodeId = best.id;
          await prefs.setString(_prefsSelectedNodeId, best.id);
          ApiClient.applyRuntimeBaseUrl(best.apiBaseUrl);
        } else {
          await prefs.setString(_prefsSelectedNodeId, _selectedNodeId);
        }
      } catch (_) {
        await prefs.setString(_prefsSelectedNodeId, _selectedNodeId);
        ApiClient.applyRuntimeBaseUrl(currentApiBaseUrl);
      }
      await prefs.setBool(_prefsFirstAutoProbeDone, true);
    } else {
      if (savedId != null && savedId.isNotEmpty) {
        _selectedNodeId = savedId;
      } else {
        _selectedNodeId = defaultNodeId;
      }
      // 已下线节点（如旧 OS）统一落到当前唯一可用节点。
      final resolvedId = nodeById(_selectedNodeId).id;
      if (resolvedId != _selectedNodeId) {
        _selectedNodeId = resolvedId;
        await prefs.setString(_prefsSelectedNodeId, resolvedId);
      } else {
        _selectedNodeId = resolvedId;
      }
      ApiClient.applyRuntimeBaseUrl(currentApiBaseUrl);
      // 老用户已有选中节点时，补记「首次已完成」，避免下次冷启动再测速。
      if (!firstAutoDone) {
        await prefs.setBool(_prefsFirstAutoProbeDone, true);
      }
    }

    ApiClient.onTransportSuccess = noteRequestSuccess;
    ApiClient.onTransportFailure = noteRequestFailure;
    _hydrated = true;
    notifyListeners();
  }

  void noteRequestSuccess() {
    if (_consecutiveFailures == 0) {
      return;
    }
    _consecutiveFailures = 0;
  }

  /// 业务 Dio 传输失败：累计满 [failureSwitchThreshold] 次后自动切到其它正常节点。
  void noteRequestFailure() {
    if (!_hydrated || _failoverInFlight) {
      return;
    }
    _consecutiveFailures += 1;
    if (_consecutiveFailures < failureSwitchThreshold) {
      return;
    }
    // 同步占坑，避免连续失败并发触发多次切换。
    _failoverInFlight = true;
    unawaited(_failoverAfterFailures());
  }

  Future<void> _failoverAfterFailures() async {
    try {
      await probeAll();
      final next = pickFastestNormal(
        probes: _probeById,
        excludeId: _selectedNodeId,
      );
      if (next == null) {
        // 没有可切节点，保留当前并重置计数，避免刷屏式探测。
        _consecutiveFailures = 0;
        return;
      }
      await selectNode(next.id);
      _consecutiveFailures = 0;
    } catch (_) {
      _consecutiveFailures = 0;
    } finally {
      _failoverInFlight = false;
    }
  }

  Future<void> selectNode(String nodeId) async {
    final node = nodeById(nodeId);
    _selectedNodeId = node.id;
    _consecutiveFailures = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsSelectedNodeId, node.id);
    // 手动/自动选过后都视为「首次流程已结束」。
    await prefs.setBool(_prefsFirstAutoProbeDone, true);
    ApiClient.applyRuntimeBaseUrl(node.apiBaseUrl);
    // 切节点后重连实时 TCP（若已启动）。
    unawaited(_reconnectRealtimeIfNeeded());
    notifyListeners();
  }

  Future<void> _reconnectRealtimeIfNeeded() async {
    try {
      await FriendRealtimeService.instance.ensureConnected(force: true);
    } catch (_) {}
  }

  Future<void> probeAll() async {
    if (_probing) {
      return;
    }
    _probing = true;
    notifyListeners();
    try {
      final results = await Future.wait(
        catalog.map((node) async {
          final result = await probeNode(node);
          return MapEntry(node.id, result);
        }),
      );
      for (final entry in results) {
        _probeById[entry.key] = entry.value;
      }
      _lastProbeAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _prefsLastProbeAtMs,
        _lastProbeAt!.millisecondsSinceEpoch,
      );
      for (final entry in results) {
        await prefs.setString(
          '$_prefsProbePrefix${entry.key}',
          _encodeProbe(entry.value),
        );
      }
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  Future<ApiNodeProbeResult> probeNode(ApiNodeDefinition node) async {
    final base = ApiClient.sanitizeBaseUrl(node.apiBaseUrl) ?? node.apiBaseUrl;
    final dio = createAppDio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: 6000,
        receiveTimeout: 6000,
        // Cloudflare 403 / 业务 401 仍说明链路可达。
        validateStatus: (_) => true,
      ),
    );
    final sw = Stopwatch()..start();
    try {
      await dio.get<dynamic>(
        '/api/v1/platform/splash',
        queryParameters: <String, dynamic>{
          'channel': IMDemoConfig.appChannel,
        },
      );
      sw.stop();
      return ApiNodeProbeResult(
        status: ApiNodeProbeStatus.normal,
        latencyMs: sw.elapsedMilliseconds,
      );
    } on DioError catch (e) {
      sw.stop();
      // 有响应即视为链路通。
      if (e.response != null) {
        return ApiNodeProbeResult(
          status: ApiNodeProbeStatus.normal,
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      return const ApiNodeProbeResult(status: ApiNodeProbeStatus.abnormal);
    } catch (_) {
      return const ApiNodeProbeResult(status: ApiNodeProbeStatus.abnormal);
    } finally {
      dio.close(force: true);
    }
  }

  static String _encodeProbe(ApiNodeProbeResult result) {
    final ms = result.latencyMs;
    return '${result.status.name}|${ms ?? ''}';
  }

  static ApiNodeProbeResult? _decodeProbe(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    final parts = text.split('|');
    if (parts.isEmpty) {
      return null;
    }
    final status = ApiNodeProbeStatus.values.firstWhere(
      (e) => e.name == parts.first,
      orElse: () => ApiNodeProbeStatus.unknown,
    );
    final ms = parts.length > 1 ? int.tryParse(parts[1]) : null;
    return ApiNodeProbeResult(status: status, latencyMs: ms);
  }
}
