import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/sangong_admin_models.dart';

void main() {
  group('SangongDrawStatus', () {
    test('parses required and missing doors', () {
      final status = SangongDrawStatus.fromJson({
        'roundId': 9,
        'doorCount': 6,
        'requiredDoors': [1, 2, 3, 4, 5, 6],
        'missingDoors': [3, 4],
        'complete': false,
        'draws': [
          {
            'door': 1,
            'rawInput': '37',
            'handLabel': '牛牛',
            'handType': 'niuniu',
          },
        ],
      });
      expect(status.roundId, 9);
      expect(status.doorsToEnter, [1, 2, 3, 4, 5, 6]);
      expect(status.missingDoors, [3, 4]);
      expect(status.drawForDoor(1)?.handLabel, '牛牛');
    });
  });

  group('SangongAdminRound', () {
    test('canSubmitBets follows bet window fields only', () {
      const open = SangongAdminRound(
        id: 1,
        betWindowOpenAt: '2026-06-22T21:48:15+08:00',
      );
      expect(open.canSubmitBets, isTrue);

      const closed = SangongAdminRound(
        id: 1,
        betWindowOpenAt: '2026-06-22T21:48:15+08:00',
        betWindowCloseAt: '2026-06-22T21:52:30+08:00',
      );
      expect(closed.canSubmitBets, isFalse);

      const awaiting = SangongAdminRound(id: 1);
      expect(awaiting.canSubmitBets, isFalse);
    });

    test('canCutoffBets allows re-cutoff after window closed', () {
      const closed = SangongAdminRound(
        id: 1,
        betWindowOpenAt: '2026-06-22T21:48:15+08:00',
        betWindowCloseAt: '2026-06-22T21:52:30+08:00',
      );
      expect(closed.canSubmitBets, isFalse);
      expect(closed.canCutoffBets, isTrue);

      const settled = SangongAdminRound(
        id: 1,
        betWindowOpenAt: '2026-06-22T21:48:15+08:00',
        betWindowCloseAt: '2026-06-22T21:52:30+08:00',
        status: 'settled',
      );
      expect(settled.canCutoffBets, isFalse);
      expect(settled.canVoidResettle, isTrue);

      const voided = SangongAdminRound(
        id: 2,
        status: 'voided',
      );
      expect(voided.isVoided, isTrue);
      expect(voided.isRoundClosed, isTrue);
    });

    test('parses periodNo and settle timestamps', () {
      final round = SangongAdminRound.fromJson({
        'id': 49,
        'periodNo': 29,
        'status': 'settled',
        'settledAt': '2026-07-11T12:00:00+08:00',
        'drawLockedAt': '2026-07-11T11:59:00+08:00',
        'betWindowCloseAt': '2026-07-11T11:50:00+08:00',
      });
      expect(round.periodNo, 29);
      expect(round.isSettled, isTrue);
      expect(round.settledAt, contains('2026-07-11'));
      expect(round.drawLockedAt, isNotEmpty);
    });
  });

  group('Sangong void / resettle models', () {
    test('parses void-settlement response', () {
      final result = SangongVoidSettlementResult.fromJson({
        'ok': true,
        'voided': {
          'roundId': 49,
          'periodNo': 29,
          'voided': [
            {'userId': 8, 'delta': -3028, 'role': 'banker'},
          ],
        },
        'round': {
          'id': 49,
          'periodNo': 29,
          'status': 'co_bank_closed',
          'settledAt': null,
          'drawLockedAt': null,
          'betWindowCloseAt': '2026-07-11T12:00:00+08:00',
        },
      });
      expect(result.ok, isTrue);
      expect(result.voided.periodNo, 29);
      expect(result.voided.voided.single.delta, -3028);
      expect(result.round?.isSettled, isFalse);
      expect(result.round?.hasBetWindowClose, isTrue);
    });

    test('parses resettle response', () {
      final result = SangongResettleResult.fromJson({
        'ok': true,
        'voided': {
          'roundId': 49,
          'periodNo': 29,
          'voided': [],
        },
        'settlement': {'total': 1},
        'round': {
          'id': 49,
          'periodNo': 29,
          'status': 'settled',
        },
      });
      expect(result.ok, isTrue);
      expect(result.settlement['total'], 1);
      expect(result.round?.canVoidResettle, isTrue);
    });

    test('empty draw status for resettle clears draws', () {
      final source = SangongDrawStatus.fromJson({
        'roundId': 9,
        'doorCount': 6,
        'bankerDoor': 2,
        'requiredDoors': [1, 2, 3, 4, 5, 6],
        'complete': true,
        'draws': [
          {'door': 1, 'rawInput': '37', 'amount': '37'},
        ],
      });
      final empty = sangongEmptyDrawStatusForResettle(source);
      expect(empty.complete, isFalse);
      expect(empty.draws, isEmpty);
      expect(empty.missingDoors, [1, 2, 3, 4, 5, 6]);
      expect(empty.bankerDoor, 2);
      expect(empty.roundId, 9);
    });
  });

  group('SangongBetPreviewResult', () {
    test('parses preview report fields', () {
      final result = SangongBetPreviewResult.fromJson({
        'preview': {
          'report': {
            'grandTotal': 299,
            'betCount': 3,
            'doorTotals': {'1': 22, '3': 55, '5': 222},
            'users': [
              {
                'nickname': '用户666',
                'grandTotal': 299,
                'doorTotals': {'2': 200, '3': 55, '5': 44},
              },
              {
                'nickname': '张三',
                'grandTotal': 100,
                'doorTotals': {'2': 100},
              },
            ],
          },
          'pendingMessageCount': 5,
          'excludedAfterCutoff': 2,
          'cutoffMessageId': 165,
          'cutoffMsgSeq': 233,
          'untilMessageId': 165,
          'excludedMessageIds': [163],
          'excludedManualCount': 1,
          'previewCloseMsgTime': '2026-06-23T12:00:00+08:00',
        },
      });
      expect(result.preview.report.grandTotal, 299);
      expect(result.preview.report.betCount, 3);
      expect(result.preview.report.doorValuesForCount(6)[0], 22);
      expect(result.preview.report.doorValuesForCount(6)[2], 55);
      expect(result.preview.report.doorValuesForCount(6)[4], 222);
      expect(result.preview.pendingMessageCount, 5);
      expect(result.preview.excludedAfterCutoff, 2);
      expect(result.preview.cutoffMessageId, 165);
      expect(result.preview.cutoffMsgSeq, 233);
      expect(result.preview.untilMessageId, 165);
      expect(result.preview.excludedMessageIds, [163]);
      expect(result.preview.excludedManualCount, 1);
      expect(result.preview.report.users.length, 2);
      expect(result.preview.report.users.first.displayName, '用户666');
      expect(result.preview.report.users.first.resolvedGrandTotal, 299);
      expect(result.preview.report.users.first.doorSummary(), '2门200  3门55  5门44');
      expect(result.preview.report.users.last.doorSummary(), '2门100');
    });

    test('parses preview report entries', () {
      final result = SangongBetPreviewResult.fromJson({
        'preview': {
          'report': {
            'grandTotal': 700,
            'entryCount': 2,
            'entries': [
              {
                'index': 1,
                'messageId': 163,
                'msgSeq': 230,
                'nickname': '张三',
                'text': '2.200',
                'doors': [2],
                'amount': 200,
                'totalAmount': 200,
                'doorCount': 1,
                'status': 'pending',
                'outcome': 'pending_sufficient',
                'source': 'im',
              },
              {
                'index': 2,
                'messageId': null,
                'nickname': '后台录入',
                'text': '3.500',
                'doors': [3],
                'amount': 500,
                'totalAmount': 500,
                'status': 'pending',
                'source': 'admin',
              },
            ],
          },
        },
      });
      expect(result.preview.report.entryCount, 2);
      expect(result.preview.report.entries.length, 2);
      final first = result.preview.report.entries.first;
      expect(first.messageId, 163);
      expect(first.msgSeq, 230);
      expect(first.displayName, '张三');
      expect(first.text, '2.200');
      expect(first.doors, [2]);
      expect(first.resolvedTotalAmount, 200);
      expect(first.canExclude, isTrue);
      expect(first.doorsLabel(), '2门');
      final admin = result.preview.report.entries.last;
      expect(admin.messageId, isNull);
      expect(admin.isAdminSource, isTrue);
      expect(admin.canExclude, isFalse);
    });

    test('falls back to preview-level users when report.users is empty', () {
      final result = SangongBetPreviewResult.fromJson({
        'preview': {
          'report': {'grandTotal': 100, 'betCount': 1},
          'users': [
            {'nickname': '李四', 'grandTotal': 100, 'doorTotals': {'1': 100}},
          ],
        },
      });
      expect(result.preview.report.users.single.displayName, '李四');
      expect(result.preview.report.users.single.resolvedGrandTotal, 100);
    });
  });

  group('SangongBetSubmitResult', () {
    test('parses submit counts and round', () {
      final result = SangongBetSubmitResult.fromJson({
        'submit': {
          'placedCount': 3,
          'failedCount': 1,
          'cutoffMessageId': 165,
          'cutoffMsgSeq': 233,
        },
        'round': {
          'id': 6,
          'betWindowCloseAt': '2026-06-22T21:52:30+08:00',
          'betWindowCloseMessageId': 165,
        },
      });
      expect(result.placedCount, 3);
      expect(result.failedCount, 1);
      expect(result.cutoffMessageId, 165);
      expect(result.cutoffMsgSeq, 233);
      expect(result.round?.id, 6);
      expect(result.round?.hasBetWindowClose, isTrue);
      expect(result.round?.betWindowCloseMessageId, 165);
      expect(result.isRecutoff, isFalse);
    });

    test('parses re-cutoff submit fields', () {
      final result = SangongBetSubmitResult.fromJson({
        'submit': {
          'placedCount': 5,
          'failedCount': 0,
          'isRecutoff': true,
          'previousCloseAt': '2026-06-22T21:52:30+08:00',
          'previousCloseMsgTime': '2026-06-22T21:52:00+08:00',
          'previousCutoffMessageId': 160,
          'cutoffMessageId': 165,
          'recutoff': {'cancelled': 2, 'requeued': 1},
          'recallSummary': {'recalled': 1, 'failed': 0},
        },
        'round': {
          'id': 6,
          'betWindowCloseAt': '2026-06-22T21:55:00+08:00',
        },
      });
      expect(result.isRecutoff, isTrue);
      expect(result.previousCutoffMessageId, 160);
      expect(result.cutoffMessageId, 165);
      expect(result.previousCloseAt, contains('2026-06-22'));
      expect(result.recutoff?.cancelled, 2);
      expect(result.recutoff?.requeued, 1);
      expect(result.recallSummary?.recalled, 1);
    });
  });

  group('SangongAdminSession', () {
    test('parses round coBank and members', () {
      final session = SangongAdminSession.fromJson({
        'round': {
          'id': 5,
          'bankerNickname': '用户666',
          'bankerDoor': 3,
          'bankerLimit': 5000,
          'coBank': {
            'poolTotal': 10000,
            'count': 2,
            'members': [
              {
                'userId': 4,
                'imUserId': 'w5bb6eu97d',
                'nickname': '用户666',
                'amount': 8000,
                'sharePercent': 80.25,
              },
            ],
          },
        },
      });

      expect(session.round?.id, 5);
      expect(session.round?.bankerNickname, '用户666');
      expect(session.round?.bankerDoor, 3);
      expect(session.round?.bankerLimit, 5000);
      expect(session.round?.hasBankerLimitDisplay, isTrue);
      expect(session.round?.coBank.poolTotal, 10000);
      expect(session.round?.coBank.members.first.sharePercent, 80.25);
      expect(
        session.round?.coBank.memberForImUserId('w5bb6eu97d')?.amount,
        8000,
      );
    });

    test('parses running session status', () {
      final session = SangongAdminSession.fromJson({
        'status': 'running',
        'session': {
          'id': 3,
          'status': 'running',
          'periodNo': 6,
          'currentRoundId': 19,
          'startedAt': '2026-06-23T01:03:44+08:00',
        },
        'round': {'id': 19, 'status': 'betting'},
      });
      expect(session.isRunning, isTrue);
      expect(session.periodNo, 6);
      expect(session.session?.id, 3);
    });

    test('parses idle session status', () {
      final session = SangongAdminSession.fromJson({
        'status': 'idle',
      });
      expect(session.isRunning, isFalse);
    });
  });

  group('SangongSessionMutationResult', () {
    test('parses start session response', () {
      final result = SangongSessionMutationResult.fromJson({
        'ok': true,
        'message': '开机成功',
        'session': {'id': 3, 'periodNo': 1, 'status': 'running'},
        'round': {'periodNo': 1, 'status': 'await_banker'},
      });
      expect(result.message, '开机成功');
      expect(result.session?.periodNo, 1);
      expect(result.round?.status, 'await_banker');
    });
  });

  group('SangongAdminUserReport', () {
    test('parses nested group object', () {
      final report = SangongAdminUserReport.fromJson({
        'userId': 4,
        'imUserId': 'w5bb6eu97d',
        'balance': 100,
        'group': {
          'groupId': 1,
          'code': 'A',
          'name': 'A组',
        },
      });
      expect(report.userId, 4);
      expect(report.balance, 100);
      expect(report.group.groupId, 1);
      expect(report.group.code, 'A');
      expect(report.group.displayLabel, 'A组');
    });
  });

  group('SangongBalanceMutationResult', () {
    test('parses user wrapper with group', () {
      final result = SangongBalanceMutationResult.fromResponse({
        'user': {
          'balance': 200,
          'group': {'groupId': 2, 'code': '1', 'name': '1组'},
        },
      });
      expect(result.balance, 200);
      expect(result.group.code, '1');
      expect(result.group.name, '1组');
    });

    test('parses top-level ledger from credit/debit response', () {
      final result = SangongBalanceMutationResult.fromResponse({
        'user': {'balance': 1500},
        'ledger': {
          'ledgerId': 88,
          'imUserId': 'player_test_01',
          'operator': '管理员张三',
          'type': 'credit',
          'typeLabel': '上分',
          'balanceChange': 500,
          'balanceAfter': 1500,
          'createdAt': '2026-07-12 19:00:00',
        },
      });
      expect(result.balance, 1500);
      expect(result.ledger?.ledgerId, 88);
      expect(result.ledger?.operator, '管理员张三');
      expect(result.ledger?.imUserId, 'player_test_01');
      expect(result.ledger?.balanceChange, 500);
    });
  });

  group('SangongUserFlowReport', () {
    test('parses official user-flow response', () {
      final flow = SangongUserFlowReport.fromJson({
        'ok': true,
        'flow': {
          'scope': 'all',
          'sessionId': null,
          'startedAt': '2026-06-23T01:03:44+08:00',
          'filters': {
            'userId': 4,
            'imUserId': 'w5bb6eu97d',
            'section': 'all',
          },
          'betFlow': [
            {
              'userId': 4,
              'nickname': '用户666',
              'sessionId': 3,
              'periodNo': 6,
              'settled': true,
              'door': 2,
              'betAmount': 200,
              'net': -200,
              'compare': '庄赢',
              'settledAt': '2026-06-24T12:55:09+08:00',
            },
            {
              'sessionId': 2,
              'periodNo': 7,
              'door': 3,
              'betAmount': 100,
              'settled': false,
              'net': null,
            },
          ],
          'counts': {'bet': 2, 'banker': 1, 'ledger': 2},
          'bankerFlow': [
            {
              'userId': 8,
              'nickname': '用户666',
              'sessionId': 3,
              'periodNo': 6,
              'role': 'banker',
              'roleLabel': '庄家',
              'totalBetAmount': 9968,
              'bankerRakePoints': 6,
              'packageAmount': 50500,
              'sharePercent': 100,
              'net': 1200,
            },
          ],
          'ledgerFlow': [
            {
              'ledgerId': 12,
              'userId': 4,
              'nickname': '用户666',
              'operator': '管理员张三',
              'type': 'credit',
              'typeLabel': '上分',
              'note': '',
              'balanceChange': 5000,
              'balanceAfter': 15000,
              'createdAt': '2026-06-23 12:30:00',
            },
            {
              'type': 'debit',
              'typeLabel': '下分',
              'balanceChange': -500,
              'balanceAfter': 14500,
            },
          ],
        },
      });

      expect(flow.scope, 'all');
      expect(flow.isAllHistory, isTrue);
      expect(flow.sessionId, isNull);
      expect(flow.imUserId, 'w5bb6eu97d');
      expect(flow.userId, 4);
      expect(flow.nickname, '用户666');
      expect(flow.betFlow, hasLength(2));
      expect(flow.betFlow.first.betAmount, 200);
      expect(flow.betFlow.first.sessionId, 3);
      expect(flow.betFlow.first.net, -200);
      expect(flow.betFlow.first.settled, isTrue);
      expect(flow.betFlow.last.net, isNull);
      expect(flow.betFlow.last.sessionId, 2);
      expect(flow.betFlow.last.settled, isFalse);
      expect(flow.counts.bet, 2);
      expect(flow.bankerFlow, hasLength(1));
      expect(flow.bankerFlow.first.displayRoleLabel, '庄家');
      expect(flow.bankerFlow.first.sessionId, 3);
      expect(flow.bankerFlow.first.totalBetAmount, 9968);
      expect(flow.bankerFlow.first.bankerRakePoints, 6);
      expect(flow.bankerFlow.first.packageAmount, 50500);
      expect(flow.counts.banker, 1);
      expect(flow.ledgerFlow, hasLength(2));
      expect(flow.ledgerFlow.first.ledgerId, 12);
      expect(flow.ledgerFlow.first.operator, '管理员张三');
      expect(flow.ledgerFlow.first.displayTypeLabel, '上分');
      expect(flow.ledgerFlow.first.balanceChange, 5000);
      expect(flow.ledgerFlow.last.isDebit, isTrue);
    });
  });
}
