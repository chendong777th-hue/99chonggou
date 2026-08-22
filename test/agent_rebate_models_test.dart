import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/agent_identity_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/agent_rebate_date_range.dart';

void main() {
  group('AgentPlayerDto', () {
    test('parses agent identity and numeric fields', () {
      final player = AgentPlayerDto.fromJson(<String, dynamic>{
        'userId': 'user-1',
        'playerNo': '7552',
        'displayName': '代理',
        'playerType': '0',
        'levelNo': 1,
        'balance': '700.0000',
        'rebateRate': 200,
        'isAgent': true,
      });

      expect(player.userId, 'user-1');
      expect(player.balance, 700);
      expect(player.rebateRate, 200);
      expect(player.isAgent, isTrue);
    });
  });

  test('parses current summary and formats financial precision', () {
    final current = AgentRebateCurrentDto.fromJson(<String, dynamic>{
      'userId': 'user-1',
      'summary': <String, dynamic>{
        'agentNo': '7552',
        'pendingRebate': '12.3456',
        'dataTime': '2026-07-13T03:16:57+08:00',
      },
      'personal': <String, dynamic>{
        'balance': '700.0000',
        'totalFlow': '12.5',
        'totalProfitLoss': '-3.25',
        'totalRebate': '1.1',
        'pendingRebate': '2.2',
        'agentPendingRebate': '98',
      },
    });

    expect(current.summary.agentNo, '7552');
    expect(current.summary.pendingRebate, 12.3456);
    expect(current.summary.dataTime, isNotNull);
    expect(current.personal?.balance, 700);
    expect(current.personal?.totalFlow, 12.5);
    expect(current.personal?.totalProfitLoss, -3.25);
    expect(current.personal?.totalRebate, 1.1);
    expect(current.personal?.pendingRebate, 2.2);
    expect(current.personal?.agentPendingRebate, 98);
    expect(formatAgentRebateAmount(700), '700');
    expect(formatAgentRebateAmount(1.23456), '1');
    expect(formatAgentRebateAmount(1.5), '2');
    expect(formatAgentRebateAmount(-1.6), '-2');
    expect(formatAgentRebateRate(50), '0.5%');
    expect(formatAgentRebateRate(100), '1%');
    expect(formatAgentRebateRate(125), '1.25%');
  });

  test('parses rebate application and status flags', () {
    final application = AgentRebateApplyDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'playerNo': '7552',
      'settlementType': 'AGENT',
      'requestId': 'RR-1',
      'taskId': 'task-1',
      'leaseToken': 'lease-1',
      'databaseGeneration': 'gen-1',
      'status': 'PROCESSING',
      'flowToConsume': 0,
      'rebateAmount': 0,
      'existing': true,
    });

    expect(application.isPending, isTrue);
    expect(application.existing, isTrue);
    expect(application.settlementType, 'AGENT');
  });

  group('AgentRebateHistoryDto', () {
    test('parses days and total summary', () {
      final history = AgentRebateHistoryDto.fromJson(<String, dynamic>{
        'userId': 'user-1',
        'startDate': '2026-07-12',
        'endDate': '2026-07-13',
        'days': <Map<String, dynamic>>[
          <String, dynamic>{
            'businessDate': '2026-07-12',
            'agentCount': 1,
            'playerCount': 2,
            'totalFlow': 12.5,
          },
        ],
        'total': <String, dynamic>{
          'agentCount': 1,
          'playerCount': 2,
          'totalFlow': 12.5,
        },
      });

      expect(history.days, hasLength(1));
      expect(history.days.single.businessDate, '2026-07-12');
      expect(history.total.totalFlow, 12.5);
    });

    test('sortAgentRebateHistoryDaysNewestFirst puts latest date first', () {
      final sorted = sortAgentRebateHistoryDaysNewestFirst([
        AgentRebateHistoryDayDto.fromJson(<String, dynamic>{
          'businessDate': '2026-08-11',
          'totalFlow': 1,
        }),
        AgentRebateHistoryDayDto.fromJson(<String, dynamic>{
          'businessDate': '2026-08-17',
          'totalFlow': 2,
        }),
        AgentRebateHistoryDayDto.fromJson(<String, dynamic>{
          'businessDate': '2026-08-16',
          'totalFlow': 3,
        }),
      ]);
      expect(
        sorted.map((day) => day.businessDate).toList(),
        <String>['2026-08-17', '2026-08-16', '2026-08-11'],
      );
    });
  });

  group('Agent descendants', () {
    test('parses list and detail fields', () {
      final list = AgentDescendantsDto.fromJson(<String, dynamic>{
        'userId': 'agent-1',
        'scope': 'direct',
        'total': 1,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'child-1',
            'playerNo': '7553',
            'displayName': '下级',
            'isAgent': true,
            'balance': '2200.0000',
            'pendingRebate': 15,
          },
        ],
      });
      final detail = AgentDescendantDetailDto.fromJson(<String, dynamic>{
        'userId': 'agent-1',
        'item': <String, dynamic>{
          'userId': 'child-1',
          'playerNo': '7553',
          'totalUp': 100,
          'totalDown': 20,
        },
        'directChildCount': 2,
        'descendantCount': 4,
        'teamTotalUp': 42000,
        'teamTotalDown': 80,
      });

      expect(list.scope, AgentDescendantScope.direct);
      expect(list.items.single.balance, 2200);
      expect(list.items.single.isAgent, isTrue);
      expect(detail.directChildCount, 2);
      expect(detail.descendantCount, 4);
      expect(detail.teamTotalUp, 42000);
      expect(detail.teamTotalDown, 80);
      expect(detail.item.totalUp, 100);
    });

    test('parses per-player history items', () {
      final history = AgentDescendantsHistoryDto.fromJson(<String, dynamic>{
        'userId': 'agent-1',
        'startDate': '2026-07-13',
        'endDate': '2026-07-13',
        'targetUserId': 'child-1',
        'total': 1,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'businessDate': '2026-07-13',
            'userId': 'child-1',
            'totalFlow': 12.5,
            'rebateRate': 150,
          },
        ],
      });

      expect(history.targetUserId, 'child-1');
      expect(history.items.single.businessDate, '2026-07-13');
      expect(history.items.single.totalFlow, 12.5);
      expect(history.items.single.rebateRate, 150);
    });

    test('history items sort newest date first', () {
      final sorted = sortAgentDescendantHistoryNewestFirst([
        const AgentDescendantHistoryItemDto(
          businessDate: '2026-08-11',
          userId: 'u1',
          playerNo: '',
          displayName: '',
          playerType: '',
          directParentUserId: '',
          balance: 0,
          totalFlow: 1,
          totalUp: 0,
          totalDown: 0,
          playerProfitLoss: 0,
          platformProfitLoss: 0,
          totalRebated: 0,
          pendingRebate: 0,
          rebateRate: 0,
        ),
        const AgentDescendantHistoryItemDto(
          businessDate: '2026-08-17',
          userId: 'u1',
          playerNo: '',
          displayName: '',
          playerType: '',
          directParentUserId: '',
          balance: 0,
          totalFlow: 2,
          totalUp: 0,
          totalDown: 0,
          playerProfitLoss: 0,
          platformProfitLoss: 0,
          totalRebated: 0,
          pendingRebate: 0,
          rebateRate: 0,
        ),
        const AgentDescendantHistoryItemDto(
          businessDate: '2026-08-16',
          userId: 'u1',
          playerNo: '',
          displayName: '',
          playerType: '',
          directParentUserId: '',
          balance: 0,
          totalFlow: 3,
          totalUp: 0,
          totalDown: 0,
          playerProfitLoss: 0,
          platformProfitLoss: 0,
          totalRebated: 0,
          pendingRebate: 0,
          rebateRate: 0,
        ),
      ]);
      expect(
        sorted.map((item) => item.businessDate).toList(),
        ['2026-08-17', '2026-08-16', '2026-08-11'],
      );
    });

    test('groups all descendants including non-agents and their downline', () {
      final grouped = AgentFirstLevelAgentsDto.fromDescendants(
        AgentDescendantsDto.fromJson(<String, dynamic>{
          'userId': 'q14gkm5swv',
          'scope': 'all',
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'userId': 'agent-child',
              'displayName': '代理下级',
              'isAgent': true,
              'directParentUserId': 'q14gkm5swv',
            },
            <String, dynamic>{
              'userId': 'kyntfkkwek',
              'playerNo': '9198',
              'displayName': '四叶草管理朵儿/',
              'isAgent': false,
              'directParentUserId': 'q14gkm5swv',
            },
            <String, dynamic>{
              'userId': 'ithlxvup5h',
              'playerNo': '9176',
              'displayName': '冬',
              'isAgent': false,
              'directParentUserId': 'kyntfkkwek',
            },
          ],
        }),
      );

      expect(grouped.agents, hasLength(2));
      expect(
        grouped.agents.map((group) => group.agent.userId),
        containsAll(<String>['agent-child', 'kyntfkkwek']),
      );
      final playerGroup = grouped.agents.singleWhere(
        (group) => group.agent.userId == 'kyntfkkwek',
      );
      expect(playerGroup.agent.isAgent, isFalse);
      expect(playerGroup.descendants.single.userId, 'ithlxvup5h');
      expect(playerGroup.descendants.single.isAgent, isFalse);
    });
  });

  group('AgentRebateDateRange', () {
    final today = DateTime(2026, 7, 13);

    test('accepts one day and inclusive 93 day range', () {
      expect(
        AgentRebateDateRange(
          start: today,
          end: today,
          today: today,
        ).inclusiveDays,
        1,
      );
      expect(
        AgentRebateDateRange(
          start: today.subtract(const Duration(days: 92)),
          end: today,
          today: today,
        ).inclusiveDays,
        93,
      );
    });

    test('rejects 94 days, reversed dates and future end', () {
      expect(
        AgentRebateDateRange.validate(
          start: today.subtract(const Duration(days: 93)),
          end: today,
          today: today,
        ),
        AgentRebateDateRangeError.exceedsMaximum,
      );
      expect(
        AgentRebateDateRange.validate(
          start: today,
          end: today.subtract(const Duration(days: 1)),
          today: today,
        ),
        AgentRebateDateRangeError.endBeforeStart,
      );
      expect(
        AgentRebateDateRange.validate(
          start: today,
          end: today.add(const Duration(days: 1)),
          today: today,
        ),
        AgentRebateDateRangeError.endAfterToday,
      );
    });
  });

  test('entry visibility requires bound + enabled + agent identity', () {
    expect(
      AgentIdentityService.canShowEntries(
        groupBound: true,
        groupEnabled: true,
        isAgent: true,
      ),
      isTrue,
    );
    for (final values in <(bool, bool, bool)>[
      (false, true, true),
      (true, false, true),
      (true, true, false),
    ]) {
      expect(
        AgentIdentityService.canShowEntries(
          groupBound: values.$1,
          groupEnabled: values.$2,
          isAgent: values.$3,
        ),
        isFalse,
      );
    }
  });

  test('parses robot group binding', () {
    final binding = RobotGroupBindingDto.fromJson({
      'groupId': '@TGS#xxxx',
      'bound': true,
      'enabled': true,
      'robotId': '@2EYHG6M5CJ',
      'machineCodeMasked': 'ABCD****JKMN',
    });
    expect(binding.isReady, isTrue);
    expect(binding.robotId, '@2EYHG6M5CJ');
  });
}
