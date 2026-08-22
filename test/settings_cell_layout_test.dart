import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';

void main() {
  testWidgets('SettingsCell keeps value and arrow aligned to the right',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(390, 844),
            devicePixelRatio: 3,
          ),
          child: Scaffold(
            body: SizedBox(
              width: 390,
              child: SettingsCell(
                title: '皮肤主题',
                value: '跟随系统',
              ),
            ),
          ),
        ),
      ),
    );

    final titleRect = tester.getRect(find.text('皮肤主题'));
    final valueRect = tester.getRect(find.text('跟随系统'));
    final arrowRect = tester.getRect(find.byIcon(Icons.chevron_right_rounded));

    expect(titleRect.left, lessThan(32));
    expect(valueRect.left, greaterThan(250));
    expect(arrowRect.center.dx, greaterThan(valueRect.right));
    expect(arrowRect.right, greaterThan(360));
  });
}
