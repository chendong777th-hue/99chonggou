import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('foreground resume reconciles deferred incoming on active chat', () {
    final globalModelSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    final coordinatorSource =
        File('lib/src/services/chat_history_recovery_coordinator.dart')
            .readAsStringSync();
    final recoverySource =
        File('lib/src/services/im_recovery_service.dart').readAsStringSync();

    expect(globalModelSource.contains('hasDeferredIncomingForResume'), isTrue);
    expect(
      globalModelSource.contains('reconcileActiveChatAfterForegroundResume'),
      isTrue,
    );
    expect(
      globalModelSource.contains('_mergeDeferredIncomingAfterBackgroundResume'),
      isTrue,
    );
    expect(
      globalModelSource.contains(
        'reconcileActiveChatAfterForegroundResume();',
      ),
      isTrue,
    );
    expect(
      coordinatorSource.contains('hasDeferredIncoming = false'),
      isTrue,
    );
    expect(recoverySource.contains('hasDeferredIncomingForResume'), isTrue);
    expect(
      globalModelSource.contains('_wasAtBottomBeforeBackgroundByConv'),
      isTrue,
    );
    expect(
      globalModelSource.contains('wasAtBottomBeforeBackground == false'),
      isTrue,
    );
    expect(
      recoverySource.contains('shouldCoalesceForegroundRequest'),
      isTrue,
    );
  });

  test('foreground resume permits one cloud newer catch-up', () {
    final chatSource = File('lib/src/chat.dart').readAsStringSync();
    final catchUpSource =
        File('lib/src/utils/chat_warm_resume_catchup.dart').readAsStringSync();

    expect(chatSource.contains('shouldAllowCloudCatchUp'), isTrue);
    expect(
        chatSource.contains('allowCloudPull: shouldAllowCloudCatchUp'), isTrue);
    expect(catchUpSource.contains("'app_resumed'"), isTrue);
    expect(catchUpSource.contains("'im_reconnected'"), isTrue);
  });
}
