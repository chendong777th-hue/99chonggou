import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/search_result_cursor.dart';

void main() {
  group('nextDisplayedCount', () {
    test('empty total', () {
      expect(
        nextDisplayedCount(current: 0, total: 0, pageSize: 80),
        0,
      );
    });

    test('first page smaller than pageSize', () {
      expect(
        nextDisplayedCount(current: 0, total: 30, pageSize: 80),
        30,
      );
    });

    test('append one page', () {
      expect(
        nextDisplayedCount(current: 80, total: 250, pageSize: 80),
        160,
      );
    });

    test('last page clamps to total', () {
      expect(
        nextDisplayedCount(current: 160, total: 200, pageSize: 80),
        200,
      );
    });

    test('already at end', () {
      expect(
        nextDisplayedCount(current: 200, total: 200, pageSize: 80),
        200,
      );
    });
  });

  group('SearchResultCursor', () {
    test('initial window uses pageSize', () {
      final cursor = SearchResultCursor(total: 500, pageSize: 80);
      expect(cursor.displayedCount, 80);
      expect(cursor.hasMore, isTrue);
    });

    test('initial window when total < pageSize', () {
      final cursor = SearchResultCursor(total: 12, pageSize: 80);
      expect(cursor.displayedCount, 12);
      expect(cursor.hasMore, isFalse);
      expect(cursor.loadMore(), isFalse);
    });

    test('empty list', () {
      final cursor = SearchResultCursor(total: 0);
      expect(cursor.displayedCount, 0);
      expect(cursor.hasMore, isFalse);
    });

    test('loadMore until end', () {
      final cursor = SearchResultCursor(total: 200, pageSize: 80);
      expect(cursor.loadMore(), isTrue);
      expect(cursor.displayedCount, 160);
      expect(cursor.loadMore(), isTrue);
      expect(cursor.displayedCount, 200);
      expect(cursor.hasMore, isFalse);
      expect(cursor.loadMore(), isFalse);
    });
  });

  group('shouldLoadMoreByScroll', () {
    test('near bottom', () {
      expect(
        shouldLoadMoreByScroll(
          pixels: 940,
          maxScrollExtent: 1000,
          itemExtent: 64,
          thresholdItems: 3,
        ),
        isTrue,
      );
    });

    test('far from bottom', () {
      expect(
        shouldLoadMoreByScroll(
          pixels: 100,
          maxScrollExtent: 1000,
          itemExtent: 64,
          thresholdItems: 3,
        ),
        isFalse,
      );
    });

    test('no scroll extent means load', () {
      expect(
        shouldLoadMoreByScroll(
          pixels: 0,
          maxScrollExtent: 0,
          itemExtent: 64,
        ),
        isTrue,
      );
    });
  });
}
