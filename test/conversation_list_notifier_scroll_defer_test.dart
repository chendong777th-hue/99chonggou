import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

void main() {
  late ConversationListNotifier notifier;
  var scrolling = false;
  var notifyCount = 0;
  late void Function() onNotify;

  setUp(() {
    notifier = ConversationListNotifier.instance;
    scrolling = false;
    notifyCount = 0;
    notifier.clearSession();
    notifier.isFeedScrolling = () => scrolling;
    onNotify = () => notifyCount++;
    notifier.addListener(onNotify);
  });

  tearDown(() {
    notifier.removeListener(onNotify);
    notifier.clearSession();
  });

  group('ConversationListNotifier scroll UI defer', () {
    test('coalesced notify defers while scrolling and flushes on scroll end',
        () async {
      scrolling = true;
      final before = notifyCount;
      notifier.scheduleCoalescedNotifyForTest('apply_store');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifyCount, before);
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isTrue);

      scrolling = false;
      notifier.flushDeferredUiNotifyIfNeeded(reason: 'scroll_end');
      expect(notifyCount, before + 1);
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isFalse);
    });

    test('max defer flushes even while still scrolling', () async {
      scrolling = true;
      final before = notifyCount;
      notifier.scheduleCoalescedNotifyForTest('apply_store');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isTrue);

      await Future<void>.delayed(
        ConversationPerfFlags.feedScrollUiNotifyMaxDefer +
            const Duration(milliseconds: 50),
      );
      expect(notifyCount, before + 1);
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isFalse);
    });

    test('pin_phase_reorder defers while scrolling and flushes on scroll end',
        () {
      scrolling = true;
      final before = notifyCount;
      notifier.notifyIfAllowedForTest('pin_phase_reorder');
      expect(notifyCount, before);
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isTrue);

      scrolling = false;
      notifier.flushDeferredUiNotifyIfNeeded(reason: 'scroll_end');
      expect(notifyCount, before + 1);
      expect(notifier.uiNotifyPendingWhileScrollingForTest, isFalse);
    });
  });
}
