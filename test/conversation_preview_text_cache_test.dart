import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';

void main() {
  late ConversationPreviewTextCache cache;

  setUp(() {
    cache = ConversationPreviewTextCache.instance;
    cache.clear();
  });

  tearDown(() {
    cache.clear();
  });

  test('message-keyed preview only returns for the same last message', () {
    cache.putStrong('c2c_alice', 'hello', messageKey: 'm1');

    expect(cache.getForMessage('c2c_alice', 'm1'), 'hello');
    expect(cache.getForMessage('c2c_alice', 'm2'), isNull);
    expect(cache.get('c2c_alice'), 'hello');
  });

  test('new preview replaces previous message key', () {
    cache.putStrong('c2c_alice', 'old', messageKey: 'm1');
    cache.putStrong('c2c_alice', 'new', messageKey: 'm2');

    expect(cache.getForMessage('c2c_alice', 'm1'), isNull);
    expect(cache.getForMessage('c2c_alice', 'm2'), 'new');
    expect(cache.get('c2c_alice'), 'new');
  });
}
