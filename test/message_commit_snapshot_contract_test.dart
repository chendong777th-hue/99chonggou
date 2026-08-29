import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final globalModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();
  final separateModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/'
    'tui_chat_separate_view_model.dart',
  ).readAsStringSync();

  test('synchronous commit result captures the complete stable boundary', () {
    expect(globalModel, contains('class MessageCommitResult'));
    for (final field in const <String>[
      'listRevision',
      'projectionRevision',
      'rawCount',
      'firstIdentity',
      'lastIdentity',
      'memoryWindowMissingNewer',
      'memoryWindowMissingOlder',
      'memoryWindowSuppressed',
      'unreadBufferedCount',
      'unreadProjectionHeld',
      'structureChanged',
      'contentChanged',
      'token',
      'generation',
    ]) {
      expect(globalModel, contains('this.$field'));
    }
    expect(globalModel, contains('MessageCommitResult setMessageList('));
    expect(globalModel, isNot(contains('Future<MessageCommitResult>')));
  });

  test('empty duplicate and structural commits all return a snapshot', () {
    expect(globalModel, contains('list.isEmpty ? null'));
    expect(globalModel, contains('previous.length != next.length'));
    expect(globalModel, contains('recordCommit: false'));
    expect(globalModel, contains('recordCommit: true'));
    expect(globalModel, contains('return _messageCommitSnapshot('));
  });

  test('known synchronous readers consume result instead of global resample',
      () {
    expect(separateModel, contains('warmOnStorage = commit.rawCount;'));
    expect(separateModel, contains("'rawAfter=\${commit.rawCount}'"));
    expect(separateModel, contains('after=\${commit.rawCount}'));
  });

  test('delete rollback is bound to exact commit token and generation', () {
    expect(globalModel, contains('isMessageCommitCurrent('));
    expect(globalModel, contains('result.token'));
    expect(globalModel, contains('result.generation'));
    expect(separateModel, contains('MessageCommitResult? deleteCommit;'));
    expect(
      separateModel,
      contains('!globalModel.isMessageCommitCurrent(deleteCommit)'),
    );
  });

  test('snapshot observes memory window and unread projection without mutation',
      () {
    expect(globalModel, contains('memoryWindowMissingNewer(conversationID)'));
    expect(globalModel, contains('_memoryWindowMissingOlder(conversationID)'));
    expect(globalModel, contains('isMemoryWindowSuppressed(conversationID)'));
    expect(globalModel, contains('unreadState.bufferedMessageKeys.length'));
    expect(
      globalModel,
      contains('_deferredUntilUserBottomConversations.contains(projectionKey)'),
    );
  });
}
