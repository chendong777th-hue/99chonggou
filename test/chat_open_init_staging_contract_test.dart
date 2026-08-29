import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/src/chat.dart').readAsStringSync();

  test('chat open stages expose one-shot privacy-safe timing milestones', () {
    for (final event in const <String>[
      'chat_open_sdk_ready_ms',
      'chat_open_history_ready_ms',
      'chat_open_metadata_ms',
      'chat_open_background_enrichment_ms',
    ]) {
      expect(source, contains("'$event'"));
    }
    expect(source, contains('if (!_chatOpenCompletedStages.add(stage))'));
    expect(source, contains("'durationMs': elapsedMs"));
    expect(source, isNot(contains("'messageText'")));
  });

  test('group network enrichment starts from post-open scheduler only', () {
    final initStart = source.indexOf('void initState()');
    final initEnd = source.indexOf('void didChangeDependencies()', initStart);
    final initBody = source.substring(initStart, initEnd);

    expect(
        initBody, isNot(contains('unawaited(_hydrateGroupDisplayForOpen())')));
    expect(initBody, isNot(contains('unawaited(_loadGroupMemberCount())')));
    expect(
      initBody,
      isNot(contains('unawaited(_fetchAndStoreBackendMuteStatus(groupId))')),
    );
    expect(source, contains('ChatPostOpenScheduler.p1Delay'));
    expect(source, contains('ChatPostOpenScheduler.p2Delay'));
    expect(source, contains("key: 'local_foundation'"));
    expect(source, contains("key: 'history_enrichment'"));
  });

  test('metadata and group game enrichment are single-flight and cancellable',
      () {
    expect(source, contains('_openGroupMetadataEnrichmentInFlight'));
    expect(source, contains('_openGroupGameEnrichmentInFlight'));
    expect(
      source,
      contains('generation != _openLifecycle.postOpenTasksGeneration'),
    );
    expect(source, contains('_isCurrentConversation(conversationId)'));
  });

  test('history commit completes history-ready stage', () {
    final initStart = source.indexOf('void initState()');
    final historyCallback = source.indexOf('didGetHistoricalMessageList:');
    final beforeHistoryCallback = source.substring(initStart, historyCallback);
    expect(source, contains("source: 'sdk_history_callback'"));
    expect(
      beforeHistoryCallback,
      isNot(contains('_ChatOpenInitStage.sdkReady')),
    );
    expect(source, contains("source: 'sdk_history_commit'"));
    expect(
      source,
      contains('_ChatOpenInitStage.historyReady'),
    );
  });

  test('chat open uses explicit ordered lifecycle phases', () {
    expect(source, contains('_openLifecycle.beginConversation()'));
    expect(source, contains('_openLifecycle.markHistoryReady('));
    expect(source, contains('_openLifecycle.markInteractive('));
    expect(source, contains('_openLifecycle.markEnriched('));
    expect(source, contains('chat_open_phase_interactive_ms'));
  });

  test('post-frame callback only registers bounded work', () {
    final callback = source.indexOf(
      'WidgetsBinding.instance.addPostFrameCallback((_) {',
      source.indexOf('void _schedulePostOpenTasks()'),
    );
    final callbackEnd = source.indexOf('\n    });', callback);
    final body = source.substring(callback, callbackEnd);
    expect(body, isNot(contains('jsonDecode(')));
    expect(body, isNot(contains('readLocalImageSizeSync(')));
    expect(body, isNot(contains('ChatImageMessagePrefetch.fromMessages(')));
  });
}
