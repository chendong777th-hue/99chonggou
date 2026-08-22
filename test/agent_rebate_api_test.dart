import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_http.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';

void main() {
  tearDown(() {
    AgentRebateHttp.clearGroup();
  });

  test('unwraps player response data and sends X-Group-Id', () async {
    AgentRebateHttp.setGroupId('@TGS#10001');
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/player');
      expect(options.headers['X-Group-Id'], '@TGS#10001');
      return {
        'code': 0,
        'message': 'ok',
        'data': {'userId': 'user-1', 'playerNo': '7552', 'isAgent': true},
      };
    });

    final result = await AgentRebateApi(dio: dio).fetchPlayer();

    expect(result.userId, 'user-1');
    expect(result.playerNo, '7552');
    expect(result.isAgent, isTrue);
  });

  test('encodes group id for robot groups and skips X-Group-Id', () async {
    AgentRebateHttp.setGroupId('@TGS#10001');
    final dio = _stubDio((options) {
      expect(options.path, '/me/robot/groups/%40TGS%2310001');
      expect(options.headers.containsKey('X-Group-Id'), isFalse);
      return {
        'code': 0,
        'data': {
          'groupId': '@TGS#10001',
          'bound': true,
          'enabled': true,
          'robotId': '@BOT',
        },
      };
    });

    final result = await AgentRebateApi(dio: dio).fetchRobotGroup('@TGS#10001');
    expect(result.isReady, isTrue);
  });

  test('submits personal rebate application', () async {
    AgentRebateHttp.setGroupId('@TGS#10001');
    final dio = _stubDio((options) {
      expect(options.path, '/me/rebate/apply');
      expect(options.method, 'POST');
      expect(options.headers['X-Group-Id'], '@TGS#10001');
      return {
        'code': 0,
        'data': {'status': 'PENDING', 'requestId': 'RR-P'},
      };
    });

    final result = await AgentRebateApi(dio: dio).submitPersonalRebateApply();
    expect(result.isPending, isTrue);
  });

  test('submits agent rebate application', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/rebate/apply');
      expect(options.method, 'POST');
      return {
        'code': 0,
        'data': {
          'userId': 'agent-1',
          'settlementType': 'AGENT',
          'requestId': 'RR-1',
          'taskId': 'task-1',
          'status': 'PENDING',
          'existing': false,
        },
      };
    });

    final result = await AgentRebateApi(dio: dio).submitAgentRebateApply();

    expect(result.settlementType, 'AGENT');
    expect(result.isPending, isTrue);
    expect(result.existing, isFalse);
  });

  test('fetches latest agent rebate application status', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/rebate/apply/status');
      expect(options.method, 'GET');
      return {
        'code': 0,
        'data': {'status': 'SUCCESS', 'requestId': 'RR-1'},
      };
    });

    final result = await AgentRebateApi(
      dio: dio,
    ).fetchAgentRebateApplyStatus();

    expect(result.isSuccess, isTrue);
    expect(result.requestId, 'RR-1');
  });

  test('sends inclusive history date query and unwraps result', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/rebate/history');
      expect(options.queryParameters['startDate'], '2026-07-13');
      expect(options.queryParameters['endDate'], '2026-07-13');
      return {
        'code': 0,
        'data': {
          'startDate': '2026-07-13',
          'endDate': '2026-07-13',
          'days': [
            {'businessDate': '2026-07-13', 'totalFlow': 8},
          ],
          'total': {'totalFlow': 8},
        },
      };
    });
    final range = AgentRebateDateRange(
      start: DateTime(2026, 7, 13),
      end: DateTime(2026, 7, 13),
      today: DateTime(2026, 7, 13),
    );

    final result = await AgentRebateApi(dio: dio).fetchHistory(range);

    expect(result.days.single.summary.totalFlow, 8);
    expect(result.total.totalFlow, 8);
  });

  test('fetches descendants with selected scope', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/descendants');
      expect(options.queryParameters['scope'], 'direct');
      return {
        'code': 0,
        'data': {
          'scope': 'direct',
          'total': 1,
          'items': [
            {'userId': 'child-1', 'playerNo': '7553'},
          ],
        },
      };
    });

    final result = await AgentRebateApi(
      dio: dio,
    ).fetchDescendants(scope: AgentDescendantScope.direct);

    expect(result.scope, AgentDescendantScope.direct);
    expect(result.items.single.userId, 'child-1');
  });

  test('fetches first-level agents with grouped descendants', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/first-level-agents');
      expect(options.queryParameters, isEmpty);
      return {
        'code': 0,
        'data': {
          'userId': 'root-agent',
          // 即使父级字段与根代理不一致，服务端已返回的 agents 也必须保留。
          'agentCount': 2,
          'descendantTotal': 3,
          'agents': [
            {
              'agent': {
                'userId': 'direct-agent',
                'directParentUserId': 'root-agent',
                'isAgent': true,
              },
              'children': [
                {
                  'item': {
                    'userId': 'level-3',
                    'directParentUserId': 'direct-agent',
                  },
                  'childCount': 1,
                  'descendantCount': 1,
                  'children': [
                    {
                      'item': {
                        'userId': 'level-4',
                        'directParentUserId': 'level-3',
                      },
                      'childCount': 0,
                      'descendantCount': 0,
                      'children': [],
                    },
                  ],
                },
              ],
              'descendantCount': 2,
              'descendants': [
                {
                  'userId': 'level-3',
                  'directParentUserId': 'direct-agent',
                },
                {
                  'userId': 'level-4',
                  'directParentUserId': 'level-3',
                },
              ],
            },
            {
              'agent': {
                'userId': 'nested-agent',
                'directParentUserId': 'direct-agent',
                'isAgent': true,
              },
              'descendantCount': 1,
              'descendants': [
                {
                  'userId': 'nested-player',
                  'directParentUserId': 'nested-agent',
                },
              ],
            },
          ],
        },
      };
    });

    final result = await AgentRebateApi(dio: dio).fetchFirstLevelAgents();

    expect(result.agentCount, 2);
    expect(result.descendantTotal, 3);
    expect(result.agents.first.agent.userId, 'direct-agent');
    expect(result.agents.last.agent.userId, 'nested-agent');
    expect(result.agents.first.children.single.item.userId, 'level-3');
    expect(
      result.agents.first.children.single.children.single.item.userId,
      'level-4',
    );
    expect(result.agents.first.descendants, hasLength(2));
  });

  test('encodes descendant id when fetching detail', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/descendants/child%2F1');
      return {
        'code': 0,
        'data': {
          'userId': 'agent-1',
          'item': {'userId': 'child/1', 'totalUp': 100, 'totalDown': 20},
          'directChildCount': 2,
          'descendantCount': 3,
          'teamTotalUp': '42000',
          'teamTotalDown': 80,
        },
      };
    });

    final result = await AgentRebateApi(
      dio: dio,
    ).fetchDescendantDetail('child/1');

    expect(result.item.userId, 'child/1');
    expect(result.descendantCount, 3);
    expect(result.item.totalUp, 100);
    expect(result.teamTotalUp, 42000);
    expect(result.teamTotalDown, 80);
  });

  test('fetches descendant history with optional target user', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/descendants/history');
      expect(options.queryParameters['startDate'], '2026-07-13');
      expect(options.queryParameters['endDate'], '2026-07-13');
      expect(options.queryParameters['userId'], 'child-1');
      return {
        'code': 0,
        'data': {
          'startDate': '2026-07-13',
          'endDate': '2026-07-13',
          'targetUserId': 'child-1',
          'total': 1,
          'items': [
            {
              'businessDate': '2026-07-13',
              'userId': 'child-1',
              'pendingRebate': 2.5,
            },
          ],
        },
      };
    });
    final range = AgentRebateDateRange.today(
      agentRebateInstantFromChinaWall(2026, 7, 13, 12),
    );

    final result = await AgentRebateApi(
      dio: dio,
    ).fetchDescendantsHistory(range, userId: 'child-1');

    expect(result.targetUserId, 'child-1');
    expect(result.items.single.pendingRebate, 2.5);
  });

  test('preserves DioError from transport', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioError(
              requestOptions: options,
              type: DioErrorType.connectTimeout,
              error: 'timeout',
            ),
          );
        },
      ),
    );

    await expectLater(
      AgentRebateApi(dio: dio).fetchCurrent(),
      throwsA(
        isA<DioError>().having(
          (error) => error.type,
          'type',
          DioErrorType.connectTimeout,
        ),
      ),
    );
  });

  test('submits CSV mode that server renders as Excel', () async {
    final dio = _stubDio((options) {
      expect(options.path, '/me/agent/rebate/history/export');
      expect(options.method, 'POST');
      expect(
        options.data,
        <String, dynamic>{
          'startDate': '2026-07-07',
          'endDate': '2026-07-13',
          'fileType': 'CSV',
          'includeDetail': true,
        },
      );
      return {
        'code': 0,
        'data': {
          'taskNo': 'ARE-1',
          'taskStatus': 'COMPLETED',
          'progress': 100,
          'async': false,
          'downloadPath': '/me/agent/rebate/history/export/ARE-1/download',
        },
      };
    });

    final task = await AgentRebateApi(dio: dio).submitHistoryExport(
      AgentRebateDateRange.recentDays(
        7,
        agentRebateInstantFromChinaWall(2026, 7, 13, 12),
      ),
    );

    expect(task.taskNo, 'ARE-1');
    expect(task.isCompleted, isTrue);
  });
}

Dio _stubDio(Map<String, dynamic> Function(RequestOptions) responder) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: responder(options),
          ),
        );
      },
    ),
  );
  return dio;
}
