import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_game/group_game_floating_entry.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expands round glyph actions and collapses', (tester) async {
    var cutoff = 0;
    var settle = 0;
    var settleImage = 0;
    var bill = 0;
    var points = 0;
    var trend = 0;
    var settings = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GroupGameFloatingEntry(
                theme: const TUITheme(),
                onOpenCutoff: () => cutoff++,
                onOpenSettle: () => settle++,
                onSendSettleImage: () => settleImage++,
                onSendSettleBill: () => bill++,
                onSendPointsImage: () => points++,
                onSendTrendImage: () => trend++,
                onOpenRulesSettings: () => settings++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('显'), findsOneWidget);
    expect(find.text('截'), findsNothing);

    await tester.tap(find.text('显'));
    await tester.pumpAndSettle();

    for (final glyph in ['截', '结', '图', '账', '分', '势', '设', '隐']) {
      expect(find.text(glyph), findsOneWidget);
    }

    await tester.tap(find.text('截'));
    await tester.tap(find.text('结'));
    await tester.tap(find.text('图'));
    await tester.tap(find.text('账'));
    await tester.tap(find.text('分'));
    await tester.tap(find.text('势'));
    await tester.tap(find.text('设'));
    expect(cutoff, 1);
    expect(settle, 1);
    expect(settleImage, 1);
    expect(bill, 1);
    expect(points, 1);
    expect(trend, 1);
    expect(settings, 1);

    await tester.tap(find.text('隐'));
    await tester.pumpAndSettle();
    expect(find.text('显'), findsOneWidget);
    expect(find.text('截'), findsNothing);
  });

  testWidgets('void-resettle shows 冲 glyph', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              GroupGameFloatingEntry(
                theme: const TUITheme(),
                settleActionLabel: '冲正重结',
                onOpenCutoff: () {},
                onOpenSettle: () {},
                onSendSettleImage: () {},
                onSendSettleBill: () {},
                onSendPointsImage: () {},
                onSendTrendImage: () {},
                onOpenRulesSettings: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('显'));
    await tester.pumpAndSettle();

    expect(find.text('冲'), findsOneWidget);
    expect(find.text('结'), findsNothing);
  });
}
