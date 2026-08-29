import 'dart:math';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors [MobileTelegramMessageContextMenu] super-long initial scroll math.
double computeSuperLongMenuScrollOffset({
  required double pressY,
  required double fullBubbleTop,
  required double bubbleHeight,
  required double viewportHeight,
  required double menuHeight,
  double gap = 8,
}) {
  final maxScroll = max(
    0.0,
    bubbleHeight + gap + menuHeight + gap - viewportHeight,
  );
  if (maxScroll <= 0) {
    return 0;
  }

  final pressOffsetInBubble = (pressY - fullBubbleTop).clamp(0.0, bubbleHeight);
  final menuReserve = menuHeight + gap * 2;
  final visibleForBubble = max(0.0, viewportHeight - menuReserve);
  var targetOffset = pressOffsetInBubble - visibleForBubble * 0.35;
  final menuVisibleOffset =
      max(0.0, bubbleHeight + gap + menuHeight - viewportHeight);
  if (targetOffset < menuVisibleOffset) {
    targetOffset = menuVisibleOffset;
  }
  if (targetOffset > maxScroll) {
    targetOffset = maxScroll;
  }
  return targetOffset;
}

void main() {
  test('super-long menu scroll keeps press point near viewport center', () {
    const bubbleTop = 200.0;
    const bubbleHeight = 1200.0;
    const viewportHeight = 500.0;
    const menuHeight = 120.0;
    const pressY = 800.0;

    final offset = computeSuperLongMenuScrollOffset(
      pressY: pressY,
      fullBubbleTop: bubbleTop,
      bubbleHeight: bubbleHeight,
      viewportHeight: viewportHeight,
      menuHeight: menuHeight,
    );

    expect(offset, greaterThan(0));
    expect(offset, lessThan(bubbleHeight));
    expect(offset + viewportHeight, greaterThan(bubbleHeight));
  });

  test('short bubble needs no scroll offset', () {
    final offset = computeSuperLongMenuScrollOffset(
      pressY: 300,
      fullBubbleTop: 250,
      bubbleHeight: 120,
      viewportHeight: 600,
      menuHeight: 120,
    );
    expect(offset, 0);
  });

  test('message row removes its root overlay before disposal', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
    final deactivateStart = source.indexOf('void deactivate()');
    final disposeStart = source.indexOf('void dispose()', deactivateStart);

    expect(deactivateStart, greaterThanOrEqualTo(0));
    expect(disposeStart, greaterThan(deactivateStart));
    final deactivateBody = source.substring(deactivateStart, disposeStart);
    expect(deactivateBody.contains('_removeTooltipBlurOverlay();'), isTrue);
  });

  test('context menu viewport prefers scrollable and reserves AppBar band', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart',
    ).readAsStringSync();
    final viewportAt = source.indexOf('Rect _messageViewportRect()');
    expect(viewportAt, greaterThanOrEqualTo(0));
    final viewportBody = source.substring(viewportAt, viewportAt + 900);
    expect(viewportBody.contains('Scrollable.maybeOf'), isTrue);
    expect(viewportBody.contains('kToolbarHeight'), isTrue);

    final safeTopAt = source.indexOf('double _chatContextMenuSafeTop()');
    expect(safeTopAt, greaterThanOrEqualTo(0));
    final safeTopBody = source.substring(safeTopAt, safeTopAt + 450);
    expect(safeTopBody.contains('kToolbarHeight'), isTrue);
    expect(safeTopBody.contains('chromeFloor'), isTrue);
  });

  test('ordinary menu keeps the live message instead of painting a copy', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart',
    ).readAsStringSync();
    expect(source, contains('The live selected message remains'));
    expect(source, isNot(contains('Widget _buildExtractedMessageRow')));
  });
}
