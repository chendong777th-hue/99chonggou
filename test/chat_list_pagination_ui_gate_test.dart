import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_pagination_ui_gate.dart';

void main() {
  group('ChatListPaginationUiGate top reach', () {
    late ChatListPaginationUiGate gate;

    setUp(() {
      gate = ChatListPaginationUiGate();
    });

    test(
      'blocks repeat load at same top reach until scrolled away or successful release',
      () {
        expect(gate.shouldAllowLoadPreviousAtTopReach(), isTrue);

        gate.markTopReachConsumedForPreviousLoad('msg:abc');
        expect(gate.shouldAllowLoadPreviousAtTopReach(), isFalse);

        gate.finishPreviousLoadInFlight();
        expect(gate.previousLoadConsumedThisTopReach, isTrue);
        expect(gate.shouldAllowLoadPreviousAtTopReach(), isFalse);

        gate.resetTopReachConsumedIfScrolledAway(
          pixels: 500,
          maxScrollExtent: 1000,
        );
        expect(gate.shouldAllowLoadPreviousAtTopReach(), isTrue);
      },
    );

    test('viewport fill can bypass top reach consumed', () {
      gate.markTopReachConsumedForPreviousLoad('msg:abc');
      expect(
        gate.shouldAllowLoadPreviousAtTopReach(bypassTopReachConsumed: true),
        isTrue,
      );
    });

    test('does not reset top reach when still near top', () {
      gate.markTopReachConsumedForPreviousLoad('msg:abc');
      gate.resetTopReachConsumedIfScrolledAway(
        pixels: 900,
        maxScrollExtent: 1000,
      );
      expect(gate.shouldAllowLoadPreviousAtTopReach(), isFalse);
    });

    test('successful page with haveMore releases latch', () {
      gate.markTopReachConsumedForPreviousLoad('msg:abc');
      gate.releaseTopReachConsumedAfterSuccessfulPage(haveMoreData: true);
      expect(gate.previousLoadConsumedThisTopReach, isFalse);
      expect(gate.lastTopReachConsumedAnchorKey, isNull);
      expect(gate.shouldAllowLoadPreviousAtTopReach(), isTrue);
    });

    test('successful page without haveMore keeps latch', () {
      gate.markTopReachConsumedForPreviousLoad('msg:abc');
      gate.releaseTopReachConsumedAfterSuccessfulPage(haveMoreData: false);
      expect(gate.previousLoadConsumedThisTopReach, isTrue);
      expect(gate.lastTopReachConsumedAnchorKey, 'msg:abc');
      expect(gate.shouldAllowLoadPreviousAtTopReach(), isFalse);
    });

    test('finishPreviousLoadInFlight does not release latch', () {
      gate.markTopReachConsumedForPreviousLoad('msg:abc');
      gate.previousLoadInFlightAnchorKey = 'msg:abc';
      gate.finishPreviousLoadInFlight();
      expect(gate.previousLoadInFlightAnchorKey, isNull);
      expect(gate.previousLoadConsumedThisTopReach, isTrue);
      expect(gate.shouldAllowLoadPreviousAtTopReach(), isFalse);
    });
  });

  group('source contracts', () {
    test('list releases latch after successful page in _loadPreviousImpl', () {
      final src = File(
        'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
      ).readAsStringSync();
      expect(src.contains('releaseTopReachConsumedAfterSuccessfulPage'), isTrue);
      final implIdx = src.indexOf('Future<void> _loadPreviousImpl');
      final releaseIdx = src.indexOf('releaseTopReachConsumedAfterSuccessfulPage');
      expect(implIdx, greaterThanOrEqualTo(0));
      expect(releaseIdx, greaterThan(implIdx));
      expect(src.contains('保留贴顶消费位'), isTrue);
      expect(src.contains('effectiveLoaded'), isTrue);
    });
  });
}
