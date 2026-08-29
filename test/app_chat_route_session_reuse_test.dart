import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_chat_route.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  tearDown(AppChatRouteRegistry.instance.reset);

  group('appChatSessionKey', () {
    test('keeps c2c and group sessions isolated for the same raw id', () {
      final c2c = V2TimConversation(
        conversationID: 'c2c_same',
        userID: 'same',
        type: 1,
      );
      final group = V2TimConversation(
        conversationID: 'group_same',
        groupID: 'same',
        type: 2,
      );

      expect(appChatSessionKey(c2c), 'c2c:same');
      expect(appChatSessionKey(group), 'group:same');
      expect(appChatSessionKey(c2c), isNot(appChatSessionKey(group)));
    });

    test('normalizes prefixed and explicit group ids to one session', () {
      final prefixed = V2TimConversation(
        conversationID: 'group_room_1',
        type: 2,
      );
      final explicit = V2TimConversation(
        conversationID: '',
        groupID: 'room_1',
        type: 2,
      );

      expect(appChatSessionKey(prefixed), 'group:room_1');
      expect(appChatSessionKey(explicit), appChatSessionKey(prefixed));
    });
  });

  test('route helper reuses an active session before creating another route',
      () {
    final source =
        File('lib/src/navigation/app_chat_route.dart').readAsStringSync();

    expect(source.contains('class AppChatRouteRegistry'), isTrue);
    expect(source.contains('activeRoute('), isTrue);
    expect(source.contains('navigator.popUntil'), isTrue);
    expect(source.contains('return existing.popped.then<T?>'), isTrue);
    expect(source.contains("ValueKey<String>('chat_session_\$sessionKey')"),
        isTrue);
  });

  testWidgets(
      'reused chat future completes only when the existing route is popped',
      (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    late BuildContext homeContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) {
            homeContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final conversation = V2TimConversation(
      conversationID: 'c2c_reused',
      userID: 'reused',
      type: 1,
    );
    final navigator = navigatorKey.currentState!;
    final existingRoute = MaterialPageRoute<String>(
      builder: (_) => const Scaffold(body: Text('existing chat')),
    );
    final existingPush = navigator.push<String>(existingRoute);
    await tester.pumpAndSettle();
    AppChatRouteRegistry.instance.register(
      navigator: navigator,
      sessionKey: appChatSessionKey(conversation),
      route: existingRoute,
    );

    final coveringRoute = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('covering page')),
    );
    final coveringPush = navigator.push<void>(coveringRoute);
    await tester.pumpAndSettle();

    var completed = false;
    final reusedFuture = openOrReuseAppChat<String>(
      homeContext,
      conversation,
    ).whenComplete(() => completed = true);
    await tester.pumpAndSettle();

    expect(existingRoute.isCurrent, isTrue);
    expect(completed, isFalse);
    await coveringPush;

    navigator.pop<String>('left-chat');
    await tester.pumpAndSettle();

    expect(await reusedFuture, 'left-chat');
    expect(await existingPush, 'left-chat');
    expect(completed, isTrue);
  });

  test('conversation list uses the reuse-aware chat opener', () {
    final source = File('lib/src/conversation.dart').readAsStringSync();

    expect(source.contains('await openOrReuseAppChat('), isTrue);
    expect(
      source.contains('await Navigator.push(\n'
          '          context,\n'
          '          appChatRoute(selectedConv'),
      isFalse,
    );
  });
}
