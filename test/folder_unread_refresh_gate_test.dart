import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/folder_unread_refresh_gate.dart';

void main() {
  setUp(() {
    FolderUnreadRefreshGate.resetForTest();
    ConversationPerfGateLog.resetCountsForTest();
  });

  tearDown(() {
    FolderUnreadRefreshGate.resetForTest();
  });

  test('busy joins coalesce to one pending kick', () async {
    final done = Completer<void>();
    FolderUnreadRefreshGate.attachInFlight(done.future);

    var kicks = 0;
    for (var i = 0; i < 100; i++) {
      expect(FolderUnreadRefreshGate.markJoinIfBusy(), isTrue);
    }
    expect(FolderUnreadRefreshGate.joinLogCountForTest, 1);
    expect(
      ConversationPerfGateLog
              .eventCountsForTest['folder_unread_single_flight_join'] ??
          0,
      1,
    );
    expect(FolderUnreadRefreshGate.hasPendingForTest, isTrue);

    FolderUnreadRefreshGate.onFlightFinished(
      done.future,
      onPendingKick: () => kicks++,
    );
    done.complete();
    await Future<void>.delayed(Duration.zero);
    expect(kicks, 1);
    expect(FolderUnreadRefreshGate.pendingKickCountForTest, 1);
    expect(FolderUnreadRefreshGate.hasInFlightForTest, isFalse);
    expect(FolderUnreadRefreshGate.hasPendingForTest, isFalse);
  });

  test('no pending means no kick after finish', () async {
    final done = Completer<void>();
    FolderUnreadRefreshGate.attachInFlight(done.future);
    var kicks = 0;
    FolderUnreadRefreshGate.onFlightFinished(
      done.future,
      onPendingKick: () => kicks++,
    );
    done.complete();
    await Future<void>.delayed(Duration.zero);
    expect(kicks, 0);
    expect(FolderUnreadRefreshGate.pendingKickCountForTest, 0);
  });

  test('completed flight does not re-enter synchronously via join', () async {
    final done = Completer<void>()..complete();
    FolderUnreadRefreshGate.attachInFlight(done.future);
    expect(FolderUnreadRefreshGate.markJoinIfBusy(), isTrue);
    var syncDepth = 0;
    var maxDepth = 0;
    void kick() {
      syncDepth++;
      if (syncDepth > maxDepth) {
        maxDepth = syncDepth;
      }
      if (syncDepth > 5) {
        fail('synchronous re-entry storm');
      }
      FolderUnreadRefreshGate.markJoinIfBusy();
      syncDepth--;
    }

    FolderUnreadRefreshGate.onFlightFinished(
      done.future,
      onPendingKick: kick,
    );
    await Future<void>.delayed(Duration.zero);
    expect(maxDepth, lessThanOrEqualTo(1));
  });

  test('tryClaimFlight is atomic: second claim fails', () {
    final a = Completer<void>();
    final b = Completer<void>();
    expect(FolderUnreadRefreshGate.tryClaimFlight(a), isNotNull);
    expect(FolderUnreadRefreshGate.tryClaimFlight(b), isNull);
    expect(FolderUnreadRefreshGate.claimFailCountForTest, 1);
    expect(FolderUnreadRefreshGate.hasPendingForTest, isTrue);
    expect(FolderUnreadRefreshGate.joinLogCountForTest, 1);
  });
}
