import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previous pagination preserves request baseline before committing', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_history_pagination_load.dart',
    ).readAsStringSync();

    expect(source.contains('previousPaginationBaseline'), isTrue);
    expect(source.contains('stableCommitBase'), isTrue);
    expect(source.contains('stableLatestBeforeCommit'), isTrue);
    expect(
        source
            .contains('applyMemoryWindow: direction != LoadDirection.previous'),
        isTrue);
  });
}
