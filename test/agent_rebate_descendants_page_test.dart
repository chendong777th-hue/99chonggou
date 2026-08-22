import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/agent_rebate_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/agent_rebate_models.dart';
import 'package:tencent_cloud_chat_demo/src/pages/agent_rebate_descendants_page.dart';

void main() {
  testWidgets('searches nicknames or player numbers and sorts metrics', (
    tester,
  ) async {
    final api = _FakeAgentRebateApi();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AgentRebateDescendantsPage(
          api: api,
          profileLoader: (userId) async => UserSearchResult(
            userId: userId,
            nickname: userId,
            avatarUrl: 'https://example.test/$userId.png',
          ),
          avatarBuilder: (_, faceUrl, showName) =>
              SizedBox(key: ValueKey<String>(faceUrl), width: 48, height: 48),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('全部下级'), findsNothing);
    expect(find.text('直属下级'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('总积分 ↓'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('https://example.test/user-ming.png')),
      findsOneWidget,
    );
    expect(find.textContaining('用户输赢'), findsWidgets);
    expect(find.textContaining('今日流水'), findsWidgets);
    expect(find.text('孙级'), findsOneWidget);
    expect(find.text('小白'), findsOneWidget);
    expect(find.text('共 6 人'), findsOneWidget);

    await tester.tap(find.text('总流水'));
    await tester.pump();
    expect(find.text('总流水 ↓'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('小红')).dy,
      lessThan(tester.getTopLeft(find.text('小明')).dy),
    );

    await tester.enterText(find.byType(TextField), '孙级');
    await tester.pump();
    expect(find.text('小明'), findsWidgets);
    expect(
      find.byWidgetPredicate((widget) => widget is Text && widget.data == '孙级'),
      findsOneWidget,
    );
    expect(find.text('小红'), findsNothing);
    expect(find.text('小白'), findsNothing);

    await tester.enterText(find.byType(TextField), '小明');
    await tester.pump();
    expect(
      find.byWidgetPredicate((widget) => widget is Text && widget.data == '小明'),
      findsOneWidget,
    );
    expect(find.text('孙级'), findsOneWidget);
    expect(find.text('小红'), findsNothing);

    await tester.enterText(find.byType(TextField), '1002');
    await tester.pump();
    expect(find.text('小红'), findsOneWidget);
    expect(find.text('小明'), findsNothing);

    await tester.enterText(find.byType(TextField), '小明');
    await tester.pump();
    await tester.tap(find.text('小明').last);
    await tester.pumpAndSettle();
    expect(find.text('直属下级'), findsOneWidget);
    expect(find.text('孙级'), findsWidgets);
    expect(find.text('团队总上分'), findsOneWidget);
    expect(find.text('团队总下分'), findsOneWidget);
    expect(find.text('42000'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(api.detailRequestCount, 1);
  });

  testWidgets('shows every record returned even when hierarchy is incomplete', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: AgentRebateDescendantsPage(
          api: _FakeAgentRebateApi(anomalousOnly: true),
          profileLoader: (_) async => null,
          avatarBuilder: (_, __, ___) => const SizedBox(width: 48, height: 48),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('正常下级'), findsOneWidget);
    expect(find.text('孤立下级'), findsOneWidget);
    expect(find.text('关系异常用户'), findsOneWidget);
    expect(find.text('共 3 人'), findsOneWidget);
  });
}

class _FakeAgentRebateApi extends AgentRebateApi {
  _FakeAgentRebateApi({this.anomalousOnly = false}) : super(dio: Dio());

  final bool anomalousOnly;

  int detailRequestCount = 0;

  @override
  Future<AgentDescendantsDto> fetchDescendants({
    AgentDescendantScope scope = AgentDescendantScope.all,
  }) async {
    if (anomalousOnly) {
      return AgentDescendantsDto.fromJson(<String, dynamic>{
        'userId': 'agent-1',
        'scope': 'all',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'userId': 'normal-user',
            'displayName': '正常下级',
            'directParentUserId': 'agent-1',
          },
          <String, dynamic>{
            'userId': 'orphan-user',
            'displayName': '孤立下级',
            'directParentUserId': 'missing-parent',
          },
          <String, dynamic>{
            'userId': 'detached-user',
            'displayName': '关系异常用户',
            'directParentUserId': 'legacy-parent',
          },
        ],
      });
    }
    return AgentDescendantsDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'scope': 'all',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'userId': 'user-ming',
          'playerNo': '1001',
          'displayName': '小明',
          'directParentUserId': 'agent-1',
          'isAgent': true,
          'balance': 500,
          'totalFlow': 100,
          'totalUp': 1,
          'totalDown': 2,
          'playerProfitLoss': 30,
        },
        <String, dynamic>{
          'userId': 'user-grandchild',
          'playerNo': '2001',
          'displayName': '孙级',
          'directParentUserId': 'user-ming',
          'balance': 999,
        },
        <String, dynamic>{
          'userId': 'user-hong',
          'playerNo': '1002',
          'displayName': '小红',
          'directParentUserId': 'agent-1',
          'isAgent': true,
          'balance': 300,
          'totalFlow': 900,
          'playerProfitLoss': -20,
        },
        <String, dynamic>{
          'userId': 'user-bai',
          'playerNo': '1003',
          'displayName': '小白',
          'directParentUserId': 'agent-1',
          'isAgent': false,
          'balance': 10,
        },
        <String, dynamic>{
          'userId': 'user-clover',
          'playerNo': '9198',
          'displayName': '四叶草',
          'directParentUserId': 'agent-1',
          'isAgent': false,
          'balance': 8,
        },
        <String, dynamic>{
          'userId': 'user-dong',
          'playerNo': '9176',
          'displayName': '冬',
          'directParentUserId': 'user-clover',
          'isAgent': false,
          'balance': 3,
        },
      ],
    });
  }

  @override
  Future<AgentDescendantDetailDto> fetchDescendantDetail(String userId) async {
    detailRequestCount++;
    return AgentDescendantDetailDto.fromJson(<String, dynamic>{
      'userId': 'agent-1',
      'item': <String, dynamic>{
        'userId': userId,
        'playerNo': '1001',
        'displayName': '小明',
        'isAgent': true,
      },
      'directChildCount': 1,
      'descendantCount': 1,
      'teamTotalUp': 42000,
      'teamTotalDown': 80,
    });
  }
}
