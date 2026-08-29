import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';

void main() {
  test('completed logout cleanup does not block the next account cleanup',
      () async {
    final service = AccountSessionService.instance;
    final releaseFirst = Completer<void>();
    var runs = 0;

    final first = service.runClearTaskForTest(() async {
      runs++;
      await releaseFirst.future;
    });
    final duplicate = service.runClearTaskForTest(() async {
      runs++;
    });

    expect(identical(first, duplicate), isTrue);
    expect(runs, 1);

    var pendingClearReleased = false;
    final waitForClear = service.waitForPendingClear().then((_) {
      pendingClearReleased = true;
    });
    await Future<void>.delayed(Duration.zero);
    expect(pendingClearReleased, isFalse);

    releaseFirst.complete();
    await first;
    await waitForClear;
    expect(pendingClearReleased, isTrue);

    await service.runClearTaskForTest(() async {
      runs++;
    });
    expect(runs, 2);
  });
}
