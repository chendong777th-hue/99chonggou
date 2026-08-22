import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('historical messages are committed without awaiting online URL lookup',
      () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final callbackStart = source.indexOf('didGetHistoricalMessageList:');
    final callbackEnd = source.indexOf(
      'messageShouldMount:',
      callbackStart,
    );

    expect(callbackStart, greaterThanOrEqualTo(0));
    expect(callbackEnd, greaterThan(callbackStart));

    final callback = source.substring(callbackStart, callbackEnd);
    expect(
      callback.contains(
        'await ChatImageMessagePrefetch.resolveOnlineUrlsForMessages',
      ),
      isFalse,
    );
    expect(
      callback.contains(
        'unawaited(\n'
        '          ChatImageMessagePrefetch.resolveOnlineUrlsForMessages',
      ),
      isTrue,
    );
  });

  test('route transition listeners are owned and cleared on dispose', () {
    final source = File('lib/src/chat.dart').readAsStringSync();

    expect(source.contains('_clearRouteTransitionListeners();'), isTrue);
    expect(
      source.contains('status != AnimationStatus.dismissed'),
      isTrue,
    );
  });

  test('chat initialization does not enter active registry twice', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final initStart = source.indexOf('void initState()');
    final initEnd = source.indexOf('void didChangeDependencies()', initStart);

    expect(initStart, greaterThanOrEqualTo(0));
    expect(initEnd, greaterThan(initStart));

    final initBody = source.substring(initStart, initEnd);
    expect(
      RegExp(r'ActiveChatRegistry\.instance\.enter\(')
          .allMatches(initBody)
          .length,
      1,
    );
  });

  test('chat leave defers bubble cache eviction into batches', () {
    final chatSource = File('lib/src/chat.dart').readAsStringSync();
    final prefetchSource =
        File('lib/utils/chat_image_message_prefetch.dart').readAsStringSync();

    expect(
      chatSource.contains(
        'ChatImageMessagePrefetch.evictBubbleCacheForMessagesAfterFrame',
      ),
      isTrue,
    );
    expect(
      prefetchSource.contains('static const _leaveEvictBatchSize = 8;'),
      isTrue,
    );
    expect(
      prefetchSource.contains('_evictBubbleProvidersInBatches(providers, end)'),
      isTrue,
    );
  });

  test('image bubbles paint network thumbs during route transition', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart',
    ).readAsStringSync();
    final buildStart = source.indexOf('Widget buildImageContent()');
    expect(buildStart, greaterThanOrEqualTo(0));
    final buildEnd = source.indexOf('return GestureDetector(', buildStart);
    expect(buildEnd, greaterThan(buildStart));
    final buildBody = source.substring(buildStart, buildEnd);

    // 转场中有 URL 即可挂网图，不再要求本 State 已解出过帧。
    expect(
      buildBody.contains("_readyImageFrameKeys.contains('net:"),
      isFalse,
    );
    expect(buildBody.contains('buildNetworkImageIfPossible()'), isTrue);

    // initImages 首帧即跑，不等 TickerMode。
    expect(source.contains('unawaited(initImages());'), isTrue);
    expect(
      source.contains(
        'runWhenTickerEnabled(\n'
        '        () => unawaited(initImages()),',
      ),
      isFalse,
    );
  });

  test('open prepare gate kicks URL resolve without blocking history', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final gateStart = source.indexOf('prepare_gate_bootstrap_done');
    expect(gateStart, greaterThanOrEqualTo(0));
    final slice = source.substring(gateStart, gateStart + 1200);
    expect(
      slice.contains('ChatImageMessagePrefetch.fromMessages(messages)'),
      isTrue,
    );
    expect(
      slice.contains(
        'ChatImageMessagePrefetch.resolveOnlineUrlsForMessages(messages)',
      ),
      isTrue,
    );
    expect(
      slice.contains(
        'await ChatImageMessagePrefetch.resolveOnlineUrlsForMessages',
      ),
      isFalse,
    );
  });
}
