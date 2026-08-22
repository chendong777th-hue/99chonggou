import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/uikit_root_navigator.dart';

void main() {
  testWidgets('overlay confirm appears above an existing root overlay',
      (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    late OverlayState overlayState;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: Builder(
          builder: (context) {
            overlayState = Overlay.of(context, rootOverlay: true);
            return const Scaffold(body: Text('chat'));
          },
        ),
      ),
    );

    final menuEntry = OverlayEntry(
      builder: (_) => const ColoredBox(
        color: Color(0xCC000000),
        child: SizedBox.expand(),
      ),
    );
    overlayState.insert(menuEntry);
    await tester.pump();

    final confirmed = showUIKitOverlayConfirmDialog(
      overlay: overlayState,
      title: '删除',
      message: '确定删除这条消息吗？',
      cancelLabel: '取消',
      confirmLabel: '删除',
    );
    await tester.pump();

    expect(find.text('确定删除这条消息吗？'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '删除').last);
    await tester.pump();
    expect(await confirmed, isTrue);

    menuEntry.remove();
    await tester.pump();
  });

  testWidgets('overlay confirm cancel does not succeed', (tester) async {
    late OverlayState overlayState;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            overlayState = Overlay.of(context, rootOverlay: true);
            return const Scaffold(body: Text('chat'));
          },
        ),
      ),
    );

    final confirmed = showUIKitOverlayConfirmDialog(
      overlay: overlayState,
      title: '撤回',
      message: '确定撤回这条消息吗？',
      cancelLabel: '取消',
      confirmLabel: '撤回',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoDialogAction, '取消'));
    await tester.pump();
    expect(await confirmed, isFalse);
  });
}
