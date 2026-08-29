import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_demo/src/utils/chat_time_divider_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 8, 27, 12, 0);

  setUp(() {
    LocaleSettings.setLocale(AppLocale.zhHans);
  });

  test('labels messages from today and yesterday explicitly', () {
    final today = DateTime(2026, 8, 27, 9, 5).millisecondsSinceEpoch ~/ 1000;
    final yesterday =
        DateTime(2026, 8, 26, 21, 30).millisecondsSinceEpoch ~/ 1000;

    expect(formatChatTimeDivider(today, now: now), '今天 09:05');
    expect(formatChatTimeDivider(yesterday, now: now), '昨天 21:30');
  });

  test('uses a concrete date for older history', () {
    final sameYear = DateTime(2026, 6, 1, 8, 15).millisecondsSinceEpoch ~/ 1000;
    final previousYear =
        DateTime(2025, 12, 31, 23, 59).millisecondsSinceEpoch ~/ 1000;

    expect(formatChatTimeDivider(sameYear, now: now), '6月1日 08:15');
    expect(formatChatTimeDivider(previousYear, now: now), '2025年12月31日 23:59');
  });
}
