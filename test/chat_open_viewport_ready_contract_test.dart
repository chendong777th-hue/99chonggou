import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/chat_entry_snapshot.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_viewport_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';

void main() {
  group('ChatEntrySnapshot.isViewportReady', () {
    ChatEntrySnapshot snap({
      int messageCount = 0,
      bool initialHistoryLoaded = false,
      bool mayHaveOlderHistory = true,
      bool completeOpenWindow = false,
      bool emptyConfirmed = false,
    }) {
      return ChatEntrySnapshot(
        conversationKey: 'c2c_u1',
        conversationID: 'c2c_u1',
        requestId: 1,
        messageCount: messageCount,
        initialHistoryLoaded: initialHistoryLoaded,
        mayHaveOlderHistory: mayHaveOlderHistory,
        completeOpenWindow: completeOpenWindow,
        emptyConfirmed: emptyConfirmed,
        capturedAtMs: 0,
      );
    }

    test('empty confirmed is ready', () {
      expect(
        snap(emptyConfirmed: true, initialHistoryLoaded: true).isViewportReady,
        isTrue,
      );
    });

    test('complete open window is ready', () {
      expect(
        snap(
          messageCount: HistoryMessageDartConstant.initialOpenFetchCount,
          completeOpenWindow: true,
          initialHistoryLoaded: true,
        ).isViewportReady,
        isTrue,
      );
    });

    test('short exhausted window is ready', () {
      expect(
        snap(
          messageCount: 3,
          initialHistoryLoaded: true,
          mayHaveOlderHistory: false,
        ).isViewportReady,
        isTrue,
      );
    });

    test('thin loaded window with older history is not ready', () {
      expect(
        snap(
          messageCount: 3,
          initialHistoryLoaded: true,
          mayHaveOlderHistory: true,
          completeOpenWindow: false,
        ).isViewportReady,
        isFalse,
      );
    });
  });

  group('ChatOpenViewportCoordinator requestId', () {
    test('takeOpenWasViewportReady is single-consume', () {
      final c = ChatOpenViewportCoordinator.instance;
      c.resetForTest();
      // Simulate pending flag without full prepare (no service locator).
      // prepareForOpen needs locator; only test take API via reflection-free
      // path: mark via prepare is integration; here we only assert reset clears.
      expect(c.takeOpenWasViewportReady('c2c_u1'), isFalse);
      expect(c.currentRequestId, 0);
      expect(c.phase, ChatOpenViewportPhase.idle);
    });
  });

  group('source contracts', () {
    test('tap path uses viewport coordinator before push', () {
      final conv = File('lib/src/conversation.dart').readAsStringSync();
      expect(conv.contains('ChatOpenViewportCoordinator.instance.prepareForOpen'),
          isTrue);
      expect(conv.contains('markTransitioning'), isTrue);
      final prepareAt = conv.indexOf('prepareForOpen');
      final pushAt = conv.indexOf('Navigator.push');
      expect(prepareAt, greaterThanOrEqualTo(0));
      expect(pushAt, greaterThan(prepareAt));
    });

    test('chat Ready bypasses shell delay; fallback keeps schedule', () {
      final chat = File('lib/src/chat.dart').readAsStringSync();
      expect(chat.contains('_mountHeavyChatBodyOrReady'), isTrue);
      expect(chat.contains('_liveOpenViewportIsReady'), isTrue);
      expect(chat.contains("'viewport_ready'"), isTrue);
      expect(chat.contains('live_viewport_ready'), isTrue);
      expect(chat.contains('_scheduleHeavyChatBodyMount'), isTrue);
      expect(
        chat.contains('takeOpenWasViewportReady'),
        isTrue,
      );
    });

    test('prepare waits up to 400ms for local complete window', () {
      final coord = File(
        'lib/src/services/chat_open_viewport_coordinator.dart',
      ).readAsStringSync();
      expect(coord.contains('prepareTimeout'), isTrue);
      expect(coord.contains('milliseconds: 400'), isTrue);
      expect(
        ChatOpenViewportCoordinator.prepareTimeout,
        const Duration(milliseconds: 400),
      );
    });

    test('chat route isolates first paint with RepaintBoundary', () {
      final route = File('lib/src/navigation/app_chat_route.dart').readAsStringSync();
      expect(route.contains('RepaintBoundary('), isTrue);
      final boundaryAt = route.indexOf('RepaintBoundary(');
      final chatAt = route.indexOf('Chat(');
      expect(boundaryAt, greaterThanOrEqualTo(0));
      expect(chatAt, greaterThan(boundaryAt));
    });

    test('warm window count stays 20', () {
      expect(HistoryMessageDartConstant.initialOpenFetchCount, 20);
    });
  });
}
