import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app lifecycle invalidates pending recovery before background teardown', () {
    final app = File('lib/src/pages/app.dart').readAsStringSync();
    expect(app, contains('ChatHistoryRecoveryCoordinator.instance.invalidateLifecycle();'));
    expect(app, contains('AppLifecycleState.paused'));
    expect(app, contains('AppLifecycleState.detached'));
  });

  test('recovery coordinator uses guard tokens for pending tasks', () {
    final source = File(
      'lib/src/services/chat_history_recovery_coordinator.dart',
    ).readAsStringSync();
    expect(source, contains('MobileAsyncCommitGuard'));
    expect(source, contains("'history-recovery'"));
    expect(source, contains('pendingToken'));
    expect(source, contains('invalidateLifecycle'));
  });

  test('conversation sync rejects work invalidated by lifecycle teardown', () {
    final source = File(
      'lib/src/services/conversation_local/conversation_sync_service.dart',
    ).readAsStringSync();
    expect(source, contains('MobileAsyncCommitGuard'));
    expect(source, contains("'conversation-sync'"));
    expect(source, contains('void invalidateLifecycle()'));
    final app = File('lib/src/pages/app.dart').readAsStringSync();
    expect(app, contains('ConversationSyncService.instance.invalidateLifecycle();'));
  });
}
