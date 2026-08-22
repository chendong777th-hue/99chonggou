import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_open_layout_ready.dart';

void main() {
  tearDown(() {
    ChatHistoryOpenLayoutReady.cancel('conv_a');
    ChatHistoryOpenLayoutReady.cancel('conv_b');
  });

  test('signal stays ready for multiple waiters (not one-shot consume)', () async {
    ChatHistoryOpenLayoutReady.begin('conv_a');
    expect(ChatHistoryOpenLayoutReady.isReady('conv_a'), isFalse);

    final first = ChatHistoryOpenLayoutReady.wait(
      'conv_a',
      timeout: const Duration(milliseconds: 200),
    );
    ChatHistoryOpenLayoutReady.signal(
      'conv_a',
      epoch: ChatHistoryOpenLayoutReady.epochOf('conv_a'),
    );
    expect(await first, isTrue);
    expect(ChatHistoryOpenLayoutReady.isReady('conv_a'), isTrue);

    final second = await ChatHistoryOpenLayoutReady.wait(
      'conv_a',
      timeout: const Duration(milliseconds: 50),
    );
    expect(second, isTrue);
    expect(ChatHistoryOpenLayoutReady.isReady('conv_a'), isTrue);
  });

  test('cancel completes waiter without marking ready', () async {
    ChatHistoryOpenLayoutReady.begin('conv_b');
    final pending = ChatHistoryOpenLayoutReady.wait(
      'conv_b',
      timeout: const Duration(milliseconds: 500),
    );
    ChatHistoryOpenLayoutReady.cancel('conv_b');
    expect(await pending, isFalse);
    expect(ChatHistoryOpenLayoutReady.isReady('conv_b'), isFalse);
  });

  test('stale epoch signal is ignored', () {
    ChatHistoryOpenLayoutReady.begin('conv_a');
    final epoch = ChatHistoryOpenLayoutReady.epochOf('conv_a');
    ChatHistoryOpenLayoutReady.begin('conv_a');
    ChatHistoryOpenLayoutReady.signal('conv_a', epoch: epoch);
    expect(ChatHistoryOpenLayoutReady.isReady('conv_a'), isFalse);
  });
}
