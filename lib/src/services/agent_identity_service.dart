import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_http.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 某群的反水入口判定结果。
class AgentRebateEntryState {
  const AgentRebateEntryState({
    this.bound = false,
    this.enabled = false,
    this.isAgent = false,
    this.robotId = '',
    this.machineCodeMasked,
  });

  final bool bound;
  final bool enabled;
  final bool isAgent;
  final String robotId;
  final String? machineCodeMasked;

  bool get canShowEntries => bound && enabled && isAgent;
}

/// 按群缓存：robot 绑定状态 + `/me/agent/player`。登出应 [clearSession]。
class AgentIdentityService {
  AgentIdentityService({AgentRebateApi? api})
      : _api = api ?? AgentRebateApi.instance;

  static final AgentIdentityService instance = AgentIdentityService();

  final AgentRebateApi _api;
  final Map<String, RobotGroupBindingDto> _bindingByGroup = {};
  final Map<String, AgentPlayerDto> _playerByGroup = {};
  final Map<String, Future<AgentRebateEntryState>> _inFlightByGroup = {};
  int _sessionGeneration = 0;

  /// 兼容旧调用：最近一次解析到的代理身份（不跨群可靠）。
  AgentPlayerDto? get cachedPlayer {
    final groupId = AgentRebateHttp.groupId;
    if (groupId == null || groupId.isEmpty) {
      return null;
    }
    return _playerByGroup[_cacheKey(groupId)];
  }

  bool get hasCachedIdentity => cachedPlayer != null;

  bool get cachedIsAgent => cachedPlayer?.isAgent ?? false;

  static bool canShowEntries({
    required bool groupBound,
    required bool groupEnabled,
    required bool isAgent,
  }) {
    return groupBound && groupEnabled && isAgent;
  }

  /// @Deprecated 旧双参门控；请用 [canShowEntries] 三参版。
  static bool canShowEntriesLegacy({
    required bool groupFeatureEnabled,
    required bool isAgent,
  }) {
    return groupFeatureEnabled && isAgent;
  }

  String _cacheKey(String groupId) {
    final normalized = ChatIdFormat.normalizeGroupId(groupId.trim());
    return normalized.isNotEmpty ? normalized : groupId.trim();
  }

  AgentRebateEntryState? cachedEntry(String groupId) {
    final key = _cacheKey(groupId);
    if (key.isEmpty) return null;
    final binding = _bindingByGroup[key];
    if (binding == null) return null;
    final player = _playerByGroup[key];
    return AgentRebateEntryState(
      bound: binding.bound,
      enabled: binding.enabled,
      isAgent: player?.isAgent ?? false,
      robotId: binding.robotId,
      machineCodeMasked: binding.machineCodeMasked,
    );
  }

  /// 进群时调用：设 `X-Group-Id` → 拉绑定 →（已开启则）拉 player。
  Future<AgentRebateEntryState> refreshForGroup(
    String groupId, {
    bool force = true,
  }) {
    final key = _cacheKey(groupId);
    if (key.isEmpty) {
      return Future.value(const AgentRebateEntryState());
    }
    AgentRebateHttp.setGroupId(key);
    if (!force) {
      final cached = cachedEntry(key);
      if (cached != null) {
        return Future.value(cached);
      }
    }
    final existing = _inFlightByGroup[key];
    if (existing != null) {
      return existing;
    }
    final generation = _sessionGeneration;
    final request = _loadForGroup(key, generation);
    _inFlightByGroup[key] = request;
    return request.whenComplete(() {
      if (identical(_inFlightByGroup[key], request)) {
        _inFlightByGroup.remove(key);
      }
    });
  }

  Future<bool> isAgent({bool refresh = false}) async {
    final groupId = AgentRebateHttp.groupId;
    if (groupId == null || groupId.isEmpty) {
      return false;
    }
    final state = await refreshForGroup(groupId, force: refresh);
    return state.isAgent;
  }

  Future<bool> refresh() => isAgent(refresh: true);

  Future<AgentRebateEntryState> _loadForGroup(
    String key,
    int generation,
  ) async {
    try {
      final binding = await _api.fetchRobotGroup(key);
      if (generation != _sessionGeneration) {
        return const AgentRebateEntryState();
      }
      _bindingByGroup[key] = binding;
      if (!binding.isReady) {
        _playerByGroup.remove(key);
        return AgentRebateEntryState(
          bound: binding.bound,
          enabled: binding.enabled,
          isAgent: false,
          robotId: binding.robotId,
          machineCodeMasked: binding.machineCodeMasked,
        );
      }

      AgentRebateHttp.setGroupId(key);
      final player = await _api.fetchPlayer();
      if (generation != _sessionGeneration) {
        return const AgentRebateEntryState();
      }
      _playerByGroup[key] = player;
      return AgentRebateEntryState(
        bound: binding.bound,
        enabled: binding.enabled,
        isAgent: player.isAgent,
        robotId: binding.robotId,
        machineCodeMasked: binding.machineCodeMasked,
      );
    } catch (_) {
      if (generation == _sessionGeneration) {
        _playerByGroup.remove(key);
      }
      final binding = _bindingByGroup[key];
      return AgentRebateEntryState(
        bound: binding?.bound ?? false,
        enabled: binding?.enabled ?? false,
        isAgent: false,
        robotId: binding?.robotId ?? '',
        machineCodeMasked: binding?.machineCodeMasked,
      );
    }
  }

  /// 反水接口返回 NOT_AGENT / PLAYER_NOT_FOUND 时清除当前群代理缓存。
  void revokeGroupAgent(String? groupId) {
    final key = _cacheKey(groupId ?? AgentRebateHttp.groupId ?? '');
    if (key.isEmpty) return;
    _playerByGroup.remove(key);
  }

  void clearSession() {
    _sessionGeneration++;
    _bindingByGroup.clear();
    _playerByGroup.clear();
    _inFlightByGroup.clear();
    AgentRebateHttp.clearGroup();
  }
}
