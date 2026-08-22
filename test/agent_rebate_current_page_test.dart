import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_current_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';

void main() {
  testWidgets('submits agent rebate application after confirmation', (
    tester,
  ) async {
    final api = _FakeAgentRebateApi();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AgentRebateCurrentPage(api: api),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('申请个人反水'), findsNothing);
    expect(find.text('申请反水'), findsOneWidget);
    expect(find.text('个人反水汇总'), findsOneWidget);
    expect(find.text('玩家余额'), findsOneWidget);
    expect(find.text('个人待反水'), findsOneWidget);
    expect(find.text('级差待结算'), findsOneWidget);
    expect(find.text('可返水'), findsNothing);
    expect(find.text('下级返水'), findsNothing);
    expect(find.text('88'), findsOneWidget);
    expect(find.textContaining('用户编号：7552'), findsOneWidget);
    expect(find.text('4'), findsOneWidget); // 个人待反水
    expect(find.text('102'), findsOneWidget); // 已反水
    expect(find.text('98'), findsOneWidget); // 级差待结算 = agentPendingRebate

    await tester.tap(find.text('申请反水'));
    await tester.pumpAndSettle();
    expect(find.text('确认级差反水'), findsOneWidget);

    await tester.tap(find.text('确认申请'));
    await tester.pump();

    expect(api.agentApplyCallCount, 1);
    expect(find.text('反水处理中，请稍候…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('反水结算成功'), findsOneWidget);
    expect(find.text('反水处理中，请稍候…'), findsNothing);
  });
}

class _FakeAgentRebateApi extends AgentRebateApi {
  _FakeAgentRebateApi() : super(dio: Dio());

  int agentApplyCallCount = 0;
  int personalApplyCallCount = 0;

  @override
  Future<AgentRebateCurrentDto> fetchCurrent() async {
    return AgentRebateCurrentDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'summary': <String, dynamic>{
        'agentNo': '7552',
        'agentName': '测试代理',
        'pendingRebate': 1234.5,
        'totalRebated': 67.89,
      },
      'personal': <String, dynamic>{
        'balance': 88,
        'totalFlow': 10,
        'totalProfitLoss': -1.5,
        'totalRebate': 102,
        'pendingRebate': 4,
        'agentPendingRebate': 98,
      },
    });
  }

  @override
  Future<AgentRebateApplyDto> fetchAgentRebateApplyStatus() async {
    return AgentRebateApplyDto.fromJson(<String, dynamic>{
      'status': agentApplyCallCount == 0 ? 'NONE' : 'SUCCESS',
    });
  }

  @override
  Future<AgentRebateApplyDto> fetchPersonalRebateApplyStatus() async {
    return AgentRebateApplyDto.fromJson(<String, dynamic>{
      'status': personalApplyCallCount == 0 ? 'NONE' : 'SUCCESS',
    });
  }

  @override
  Future<AgentRebateApplyDto> submitAgentRebateApply() async {
    agentApplyCallCount++;
    return AgentRebateApplyDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'settlementType': 'AGENT',
      'requestId': 'RR-1',
      'taskId': 'task-1',
      'status': 'PENDING',
      'existing': false,
    });
  }

  @override
  Future<AgentRebateApplyDto> submitPersonalRebateApply() async {
    personalApplyCallCount++;
    return AgentRebateApplyDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'settlementType': 'PERSONAL',
      'requestId': 'RR-P1',
      'taskId': 'task-p1',
      'status': 'PENDING',
      'existing': false,
    });
  }
}
