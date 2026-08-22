import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/chat_host_app_bar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

void main() {
  const conversationID = 'peer_a';

  Widget wrap(Widget home) {
    return MaterialApp(
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
  }

  testWidgets('normal chrome has back and no cancel', (tester) async {
    final store = ChatUiStateStore();
    await tester.pumpWidget(
      wrap(
        Scaffold(
          appBar: ChatHostAppBar(
            theme: const TUITheme(),
            uiStateStore: store,
            conversationID: conversationID,
            observeMultiSelect: true,
            title: const Text('阿伦'),
            actions: const [Icon(Icons.call)],
            onCancelMultiSelect: () {},
          ),
        ),
      ),
    );

    expect(find.text('阿伦'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('取消'), findsNothing);
    expect(find.byIcon(Icons.call), findsOneWidget);
  });

  testWidgets('multi-select shows cancel and selected count', (tester) async {
    final store = ChatUiStateStore();
    store.setMultiSelect(conversationID, true);
    var cancelled = 0;
    await tester.pumpWidget(
      wrap(
        Scaffold(
          appBar: ChatHostAppBar(
            theme: const TUITheme(),
            uiStateStore: store,
            conversationID: conversationID,
            observeMultiSelect: true,
            title: const Text('阿伦'),
            actions: const [Icon(Icons.call)],
            onCancelMultiSelect: () => cancelled++,
          ),
        ),
      ),
    );

    expect(find.text('选择消息'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pump();
    expect(cancelled, 1);
  });

  testWidgets('selected count updates after toggling a message', (tester) async {
    final store = ChatUiStateStore();
    store.setMultiSelect(conversationID, true);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          appBar: ChatHostAppBar(
            theme: const TUITheme(),
            uiStateStore: store,
            conversationID: conversationID,
            observeMultiSelect: true,
            title: const Text('阿伦'),
            actions: const [],
            onCancelMultiSelect: () {},
          ),
        ),
      ),
    );
    expect(find.text('选择消息'), findsOneWidget);

    store.setMessageSelected(conversationID, 'msg_1', true);
    await tester.pump();
    expect(find.text('已选择1条'), findsOneWidget);
  });

  testWidgets('shell does not observe multi-select', (tester) async {
    final store = ChatUiStateStore();
    store.setMultiSelect(conversationID, true);
    await tester.pumpWidget(
      wrap(
        Scaffold(
          appBar: ChatHostAppBar(
            theme: const TUITheme(),
            uiStateStore: store,
            conversationID: conversationID,
            observeMultiSelect: false,
            title: const Text('阿伦'),
            actions: const [],
            onCancelMultiSelect: () {},
          ),
        ),
      ),
    );
    expect(find.text('阿伦'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('system back exits multi-select instead of popping', (tester) async {
    final store = ChatUiStateStore();
    store.setMultiSelect(conversationID, true);
    await tester.pumpWidget(
      wrap(
        ChatMultiSelectPopGuard(
          uiStateStore: store,
          conversationID: conversationID,
          onCancelMultiSelect: () =>
              store.setMultiSelect(conversationID, false),
          child: const Scaffold(body: Text('chat-body')),
        ),
      ),
    );

    expect(find.text('chat-body'), findsOneWidget);
    final notified = await tester.binding.handlePopRoute();
    expect(notified, isTrue);
    await tester.pump();
    expect(store.isMultiSelect(conversationID), isFalse);
    expect(find.text('chat-body'), findsOneWidget);
  });

  test('source contract: mobile chat hosts multi-select chrome', () {
    final chat = File('lib/src/chat.dart').readAsStringSync();
    expect(chat.contains('ChatHostAppBar'), isTrue);
    expect(chat.contains('ChatMultiSelectPopGuard'), isTrue);
    expect(chat.contains('_exitChatMultiSelect'), isTrue);
    expect(chat.contains('observeMultiSelect: headerInteractive'), isTrue);
  });
}
