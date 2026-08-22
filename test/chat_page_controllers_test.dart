import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/c2c_send_permission_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_draft_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_group_page_side_controller.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_open_lifecycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/controllers/history_pagination_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/input_panel_controller.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/media_work_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/record_input_state.dart';

void main() {
  group('InputPanelController', () {
    test('switchToKeyboard closes accessories', () {
      final panel = InputPanelController()
        ..showEmojiPanel = true
        ..showMore = true;
      panel.switchToKeyboard();
      expect(panel.showKeyboard, isTrue);
      expect(panel.showEmojiPanel, isFalse);
      expect(panel.showMore, isFalse);
      expect(panel.showSendSoundText, isFalse);
    });

    test('hideAccessoryPanels keeps keyboard flag', () {
      final panel = InputPanelController()
        ..showKeyboard = true
        ..showMore = true;
      panel.hideAccessoryPanels();
      expect(panel.showKeyboard, isTrue);
      expect(panel.isAnyAccessoryOpen, isFalse);
    });
  });

  group('ChatDraftController', () {
    test('debounce persists once', () async {
      final draft = ChatDraftController();
      var persistCount = 0;
      String? last;
      draft.onChanged('hello', persist: (raw, _) {
        persistCount++;
        last = raw;
      });
      draft.onChanged('hello world', persist: (raw, _) {
        persistCount++;
        last = raw;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(persistCount, 1);
      expect(last, 'hello world');
      draft.dispose();
    });
  });

  group('C2cSendPermissionController', () {
    test('blocked / checking helpers', () {
      final c = C2cSendPermissionController();
      expect(c.isChecking(true, true), isTrue);
      expect(c.applyResolved(false), isTrue);
      expect(c.isBlocked(true), isTrue);
      expect(c.applyResolved(false), isFalse);
      expect(c.applyResolved(null), isFalse);
      c.dispose();
    });

    test('notifies only when visible permission changes', () {
      final c = C2cSendPermissionController();
      var notifyCount = 0;
      c.addListener(() => notifyCount++);

      c.canMessage = false;
      expect(notifyCount, 1);
      c.canMessage = false;
      expect(notifyCount, 1);
      c.canMessage = true;
      expect(notifyCount, 2);
      c.trustedInitialCanMessage = true;
      expect(notifyCount, 2);
      c.trustedInitialCanMessage = true;
      expect(notifyCount, 2);

      c.dispose();
    });

    test(
        'setter does not fire in-flight callback; applyRelationBlocked does once',
        () {
      final c = C2cSendPermissionController();
      var blockedCount = 0;
      c.onTransitionToBlocked = () => blockedCount++;

      c.canMessage = true;
      c.canMessage = false;
      expect(blockedCount, 0);
      expect(c.applyResolved(true), isTrue);
      expect(c.applyResolved(false), isTrue);
      expect(blockedCount, 0);

      c.canMessage = true;
      c.applyRelationBlocked();
      expect(c.canMessage, isFalse);
      expect(blockedCount, 1);
      c.applyRelationBlocked();
      expect(blockedCount, 1);
      c.dispose();
    });
  });

  group('ChatGroupPageSideController / ChatOpenLifecycle', () {
    test('disable group game resets float visibility', () {
      final side = ChatGroupPageSideController()
        ..groupGameEnabled = true
        ..groupGameFloatVisible = false;
      side.disableGroupGame();
      expect(side.groupGameEnabled, isFalse);
      expect(side.groupGameFloatVisible, isTrue);
    });

    test('lifecycle reset clears gates', () {
      final life = ChatOpenLifecycle()
        ..postOpenTasksScheduled = true
        ..openHistoryGateConvKey = 'c2c_1';
      life.resetForDispose();
      expect(life.postOpenTasksScheduled, isFalse);
      expect(life.openHistoryGateConvKey, isEmpty);
    });

    test('post-open generation invalidates an older task batch', () {
      final life = ChatOpenLifecycle();
      final firstGeneration = life.beginPostOpenTasks();
      expect(life.postOpenTasksScheduled, isTrue);

      life.cancelPendingPostOpenTasks();
      final secondGeneration = life.beginPostOpenTasks();

      expect(secondGeneration, greaterThan(firstGeneration));
      expect(life.postOpenTasksGeneration, secondGeneration);
    });

    test('post-open work waits for history gate and survives gate errors',
        () async {
      final life = ChatOpenLifecycle();
      final gate = Completer<void>();
      life.openHistoryGate = gate.future;
      var completed = false;
      final waiting = life.waitForOpenHistoryGate().then((_) {
        completed = true;
      });

      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      gate.complete();
      await waiting;
      expect(completed, isTrue);

      life.openHistoryGate = Future<void>.error(StateError('failed'));
      await expectLater(life.waitForOpenHistoryGate(), completes);

      final preparationGate = Completer<void>();
      life.openHistoryGate = Future<void>.value();
      life.openHistoryPreparationGate = preparationGate.future;
      var preparationCompleted = false;
      final preparationWaiting = life
          .waitForOpenHistoryPreparationGate()
          .then((_) => preparationCompleted = true);
      await Future<void>.delayed(Duration.zero);
      expect(preparationCompleted, isFalse);
      preparationGate.complete();
      await preparationWaiting;
      expect(preparationCompleted, isTrue);

      life.openHistoryPreparationGate = Future<void>.error(
        StateError('preparation failed'),
      );
      await expectLater(
        life.waitForOpenHistoryPreparationGate(),
        completes,
      );
    });
  });

  group('HistoryPaginationController', () {
    test('resetForConversationInit only clears archive triple', () {
      final p = HistoryPaginationController()
        ..haveMoreData = true
        ..archiveOlderActive = true
        ..archiveOlderExhausted = true
        ..suppressArchiveUntilSdkHistory = true
        ..previousPaginationInFlight = true;
      p.historyLoadingKeys.add('k');
      p.resetForConversationInit();
      expect(p.archiveOlderActive, isFalse);
      expect(p.archiveOlderExhausted, isFalse);
      expect(p.suppressArchiveUntilSdkHistory, isFalse);
      expect(p.haveMoreData, isTrue);
      expect(p.previousPaginationInFlight, isTrue);
      expect(p.historyLoadingKeys, contains('k'));
    });
  });

  group('extracted enums', () {
    test('record and media states expose expected values', () {
      expect(RecordInputState.values.length, 6);
      expect(MediaWorkState.sending.index, greaterThan(0));
    });
  });
}
