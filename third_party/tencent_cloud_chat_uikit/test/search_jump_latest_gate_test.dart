import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/search_jump_latest_gate.dart';

void main() {
  group('SearchJumpLatestGate.shouldAllowLatestPagination', () {
    test('notShowLatest + haveMoreLatest → allow', () {
      expect(
        SearchJumpLatestGate.shouldAllowLatestPagination(
          position: HistoryMessagePosition.notShowLatest,
          haveMoreLatestData: true,
          memoryWindowMissingNewer: false,
        ),
        isTrue,
      );
    });

    test('notShowLatest + no more latest + no missing → deny', () {
      expect(
        SearchJumpLatestGate.shouldAllowLatestPagination(
          position: HistoryMessagePosition.notShowLatest,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: false,
        ),
        isFalse,
      );
    });

    test('notShowLatest + memoryWindowMissingNewer → allow', () {
      expect(
        SearchJumpLatestGate.shouldAllowLatestPagination(
          position: HistoryMessagePosition.notShowLatest,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: true,
        ),
        isTrue,
      );
    });

    test('bottom → allow', () {
      expect(
        SearchJumpLatestGate.shouldAllowLatestPagination(
          position: HistoryMessagePosition.bottom,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: false,
        ),
        isTrue,
      );
    });

    test('awayTwoScreen + no missing + no more latest → deny', () {
      expect(
        SearchJumpLatestGate.shouldAllowLatestPagination(
          position: HistoryMessagePosition.awayTwoScreen,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: false,
        ),
        isFalse,
      );
    });
  });

  group('SearchJumpLatestGate.shouldSkipLatestWhileReadingHistory', () {
    test('skips only when reading history with no fill work', () {
      expect(
        SearchJumpLatestGate.shouldSkipLatestWhileReadingHistory(
          isReadingHistory: true,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: false,
          forceReloadNewest: false,
        ),
        isTrue,
      );
    });

    test('does not skip when haveMoreLatestData', () {
      expect(
        SearchJumpLatestGate.shouldSkipLatestWhileReadingHistory(
          isReadingHistory: true,
          haveMoreLatestData: true,
          memoryWindowMissingNewer: false,
          forceReloadNewest: false,
        ),
        isFalse,
      );
    });

    test('does not skip when forceReloadNewest', () {
      expect(
        SearchJumpLatestGate.shouldSkipLatestWhileReadingHistory(
          isReadingHistory: true,
          haveMoreLatestData: false,
          memoryWindowMissingNewer: false,
          forceReloadNewest: true,
        ),
        isFalse,
      );
    });
  });
}
