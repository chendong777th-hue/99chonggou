import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('history page labels available rebate as team total rebate', () {
    final page = File(
      'lib/src/pages/agent_rebate_history_page.dart',
    ).readAsStringSync();
    expect(page.contains("zhHans: '团队总反水'"), isTrue);
    expect(page.contains('availableRebateLabel: teamTotalRebateLabel'), isTrue);
    expect(page.contains("zhHans: '可反水'"), isFalse);
  });
}
