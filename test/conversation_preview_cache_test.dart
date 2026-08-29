import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/conversation_preview_item.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_preview_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('preview cache is isolated by owner and ignores legacy cache', () async {
    final legacy = await SharedPreferences.getInstance();
    await legacy.setString(
      'conversation_preview_cache_v1_c2c',
      '[{"conversationId":"c2c_legacy","title":"legacy"}]',
    );

    expect(
      await ConversationPreviewCache.load('c2c', ownerUserId: 'account_a'),
      isEmpty,
    );

    await ConversationPreviewCache.save(
      'c2c',
      const <ConversationPreviewItem>[
        ConversationPreviewItem(
          conversationId: 'c2c_peer_a',
          scope: 'c2c',
          title: 'A',
          subtitle: 'message',
          faceUrl: '',
          unreadCount: 1,
          timestampMs: 1,
          pinned: false,
        ),
      ],
      ownerUserId: 'account_a',
    );

    expect(
      (await ConversationPreviewCache.load(
        'c2c',
        ownerUserId: 'account_a',
      ))
          .single
          .conversationId,
      'c2c_peer_a',
    );
    expect(
      await ConversationPreviewCache.load('c2c', ownerUserId: 'account_b'),
      isEmpty,
    );

    await ConversationPreviewCache.clearLegacyKeys();
    expect(
      (await SharedPreferences.getInstance()).getString(
        'conversation_preview_cache_v1_c2c',
      ),
      isNull,
    );
  });

  test('clearForOwner removes only the selected account preview', () async {
    final itemA = ConversationPreviewItem(
      conversationId: 'c2c_peer_a',
      scope: 'c2c',
      title: 'A',
      subtitle: 'from A',
      faceUrl: '',
      unreadCount: 1,
      timestampMs: 1,
      pinned: false,
    );
    final itemB = ConversationPreviewItem(
      conversationId: 'c2c_peer_b',
      scope: 'c2c',
      title: 'B',
      subtitle: 'from B',
      faceUrl: '',
      unreadCount: 2,
      timestampMs: 2,
      pinned: false,
    );
    await ConversationPreviewCache.save(
      'c2c',
      [itemA],
      ownerUserId: 'account_a',
    );
    await ConversationPreviewCache.save(
      'c2c',
      [itemB],
      ownerUserId: 'account_b',
    );

    await ConversationPreviewCache.clearForOwner('account_a');

    expect(
      await ConversationPreviewCache.load(
        'c2c',
        ownerUserId: 'account_a',
      ),
      isEmpty,
    );
    expect(
      await ConversationPreviewCache.load(
        'c2c',
        ownerUserId: 'account_b',
      ),
      hasLength(1),
    );
  });
}
