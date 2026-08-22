import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/agent_rebate_floating_entry.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('expands and opens downline and history actions', (tester) async {
    var descendantsOpenCount = 0;
    var rebateOpenCount = 0;
    var historyOpenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              AgentRebateFloatingEntry(
                theme: const TUITheme(),
                onOpenDescendants: () => descendantsOpenCount++,
                onOpenRebate: () => rebateOpenCount++,
                onOpenHistory: () => historyOpenCount++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('显'), findsOneWidget);
    expect(find.text('查'), findsNothing);

    await tester.tap(find.text('显'));
    await tester.pumpAndSettle();

    expect(find.text('查'), findsOneWidget);
    expect(find.text('反'), findsOneWidget);
    expect(find.text('历'), findsOneWidget);
    expect(find.text('隐'), findsOneWidget);

    await tester.tap(find.text('查'));
    await tester.tap(find.text('反'));
    await tester.tap(find.text('历'));
    expect(descendantsOpenCount, 1);
    expect(rebateOpenCount, 1);
    expect(historyOpenCount, 1);

    await tester.tap(find.text('隐'));
    await tester.pumpAndSettle();
    expect(find.text('显'), findsOneWidget);
    expect(find.text('查'), findsNothing);
    expect(find.text('反'), findsNothing);
    expect(find.text('历'), findsNothing);
  });
}
