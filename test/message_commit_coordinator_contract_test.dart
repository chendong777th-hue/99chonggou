import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final globalModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();

  test('authoritative writes stay synchronous behind snapshot boundary', () {
    expect(globalModel, contains('MessageCommitResult setMessageList('));
    expect(globalModel, contains('_messageListMap[storageKey] = sorted;'));
    expect(globalModel, contains('_messageCommitCoordinator.stage('));
    expect(globalModel, isNot(contains('Future<MessageCommitResult>')));
  });

  test('coordinator does not fetch history or change pagination anchors', () {
    final coordinator = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'message_commit_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, isNot(contains('getHistoryMessageList')));
    expect(coordinator, isNot(contains('lastMsgID')));
    expect(coordinator, isNot(contains('lastMsgSeq')));
    expect(coordinator, contains('expectedFirstIdentity'));
    expect(coordinator, contains('expectedLastIdentity'));
    expect(coordinator, contains('MobileAsyncCommitGuard'));
    expect(coordinator, contains("'message-commit'"));
    expect(coordinator, contains('_commitGuard.canCommit(entry.value.commitToken)'));
    expect(coordinator, isNot(contains('package:tencent_cloud_chat_demo/')));
    expect(
      coordinator,
      contains('package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart'),
    );
  });

  test('row and progress mutations retain row-local presentation', () {
    expect(globalModel, contains("source: 'row_local'"));
    expect(globalModel, contains("source: 'status_progress'"));
    expect(globalModel, contains('requiresListRevision: false'));
    expect(globalModel, contains('MessageMutationType.removeOrRevoke'));
  });
}
