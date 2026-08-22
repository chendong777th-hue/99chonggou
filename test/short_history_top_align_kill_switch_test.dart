import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_list_route_scroll_restore.dart';

void main() {
  test('short history top alignment kill switch defaults to off (bottom align)',
      () {
    expect(
      ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled,
      isFalse,
    );
  });

  test('clearShortHistoryAlignmentLatch zeros spacer and latch', () {
    final route = ChatListRouteScrollRestore()
      ..shortHistoryAlignmentLatched = true
      ..shortHistoryBottomSpacerHeight = 522
      ..shortHistoryContentHeight = 154
      ..shortHistoryContentHeightMeasured = true;
    route.clearShortHistoryAlignmentLatch();
    expect(route.shortHistoryAlignmentLatched, isFalse);
    expect(route.shortHistoryBottomSpacerHeight, 0);
    expect(route.shortHistoryContentHeight, -1);
    expect(route.shortHistoryContentHeightMeasured, isFalse);
  });

  test('underfilled cached history may silently paginate after reveal', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    final fillStart = source.indexOf(
      'void _scheduleShortViewportHistoryFill(_PreviousLoadAnchor? anchor)',
    );
    final fillEnd = source.indexOf(
      'void _scheduleShortHistoryTopAlignment(',
      fillStart,
    );
    final fillSource = source.substring(fillStart, fillEnd);

    expect(fillSource, isNot(contains('openedWithCachedHistory)')));
    expect(fillSource, isNot(contains('_historyOpenRevealReady ||')));
    expect(
      fillSource,
      contains('allowAfterRevealForViewportFill: true'),
    );
    expect(fillSource, contains('position.maxScrollExtent > 1'));
    expect(fillSource, contains('!widget.model.haveMoreData'));
  });

  test('underfilled open window stays hidden until first screen is complete',
      () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    expect(source, contains('_isCompleteCachedOpenWindow'));
    expect(
      source,
      contains("source: 'opened_with_cache_bottom_align'"),
    );
    expect(
      source,
      contains('if (_isCompleteCachedOpenWindow(globalModel))'),
    );
    expect(
      source,
      contains('if (!_historyOpenRevealPainted)'),
    );
    expect(source, contains('_resetHistoryOpenRevealGate(resetPainted: false)'));
    expect(source, contains('opacity: 0'));
    expect(
      source,
      contains('!_isCompleteCachedOpenWindow(widget.model.globalModel)'),
    );
  });

  test('short reveal wait cannot spin forever when top-align is disabled', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'if (!ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled) {\n'
        '          _scheduleHistoryOpenRevealWait(shortHistory: false);',
      ),
    );
    expect(source, contains("source: 'short_measure_starve'"));
    expect(
      source,
      contains(
        'ChatListRouteScrollRestore.shortHistoryTopAlignmentEnabled &&\n'
        '            (_routeScroll.shortHistoryAlignmentLatched ||',
      ),
    );
  });

  test('open gate does not bump layout epoch after list already signaled', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    expect(
      source,
      contains('if (ChatHistoryOpenLayoutReady.isReady(convKey))'),
    );
    expect(
      source,
      contains('不要二次 begin 抬 epoch'),
    );
  });
}
