import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/user_profile/user_profile_game_ledger_floating_entry.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows ledger glyph and opens on tap', (tester) async {
    var ledgerOpenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              UserProfileGameLedgerFloatingEntry(
                theme: const TUITheme(),
                onOpenLedger: () => ledgerOpenCount++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('流'), findsOneWidget);
    expect(find.text('显'), findsNothing);
    expect(find.text('隐'), findsNothing);

    await tester.tap(find.text('流'));
    expect(ledgerOpenCount, 1);
  });
}
