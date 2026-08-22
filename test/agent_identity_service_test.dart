import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_http.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';

void main() {
  // 用数字公开群 ID，避免 normalize 成社群完整前缀后对不上 fake map key。
  const groupA = '@TGS#10001';
  const groupB = '@TGS#10002';

  tearDown(() {
    AgentRebateHttp.clearGroup();
  });

  test('caches per group and does not cross-contaminate', () async {
    final api = _FakeAgentRebateApi()
      ..bindings[groupA] = const RobotGroupBindingDto(
        groupId: groupA,
        bound: true,
        enabled: true,
      )
      ..bindings[groupB] = const RobotGroupBindingDto(
        groupId: groupB,
        bound: true,
        enabled: true,
      )
      ..players[groupA] = _player(isAgent: true)
      ..players[groupB] = _player(isAgent: false);
    final service = AgentIdentityService(api: api);

    final a = await service.refreshForGroup(groupA);
    expect(a.canShowEntries, isTrue);
    expect(api.playerCallCount, 1);

    final aAgain = await service.refreshForGroup(groupA, force: false);
    expect(aAgain.canShowEntries, isTrue);
    expect(api.playerCallCount, 1);

    final b = await service.refreshForGroup(groupB);
    expect(b.canShowEntries, isFalse);
    expect(api.playerCallCount, 2);
  });

  test('hides entry when group not bound or not enabled', () async {
    final api = _FakeAgentRebateApi()
      ..bindings[groupA] = const RobotGroupBindingDto(
        groupId: groupA,
        bound: true,
        enabled: false,
      );
    final service = AgentIdentityService(api: api);

    final state = await service.refreshForGroup(groupA);
    expect(state.bound, isTrue);
    expect(state.enabled, isFalse);
    expect(state.isAgent, isFalse);
    expect(api.playerCallCount, 0);
  });

  test('clearSession invalidates an in-flight identity result', () async {
    final completer = Completer<AgentPlayerDto>();
    final api = _FakeAgentRebateApi()
      ..bindings[groupA] = const RobotGroupBindingDto(
        groupId: groupA,
        bound: true,
        enabled: true,
      )
      ..pendingPlayer = completer.future;
    final service = AgentIdentityService(api: api);

    final result = service.refreshForGroup(groupA);
    service.clearSession();
    completer.complete(_player(isAgent: true));

    final state = await result;
    expect(state.canShowEntries, isFalse);
    expect(service.cachedEntry(groupA), isNull);
  });

  test('canShowEntries requires bound + enabled + isAgent', () {
    expect(
      AgentIdentityService.canShowEntries(
        groupBound: true,
        groupEnabled: true,
        isAgent: true,
      ),
      isTrue,
    );
    expect(
      AgentIdentityService.canShowEntries(
        groupBound: true,
        groupEnabled: false,
        isAgent: true,
      ),
      isFalse,
    );
  });
}

AgentPlayerDto _player({required bool isAgent}) {
  return AgentPlayerDto(
    userId: 'user-1',
    playerNo: '7552',
    displayName: '代理',
    playerType: '0',
    levelNo: 1,
    balance: 0,
    rebateRate: 50,
    isAgent: isAgent,
  );
}

class _FakeAgentRebateApi extends AgentRebateApi {
  _FakeAgentRebateApi() : super(dio: Dio());

  final Map<String, RobotGroupBindingDto> bindings = {};
  final Map<String, AgentPlayerDto> players = {};
  Future<AgentPlayerDto>? pendingPlayer;
  int playerCallCount = 0;

  @override
  Future<RobotGroupBindingDto> fetchRobotGroup(String groupId) async {
    return bindings[groupId] ??
        RobotGroupBindingDto(groupId: groupId, bound: false, enabled: false);
  }

  @override
  Future<AgentPlayerDto> fetchPlayer() async {
    playerCallCount++;
    final pending = pendingPlayer;
    if (pending != null) return pending;
    final groupId = AgentRebateHttp.groupId ?? '';
    final player = players[groupId];
    if (player == null) {
      throw StateError('no player for $groupId');
    }
    return player;
  }
}
