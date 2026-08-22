import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_store.dart';

MomentPost _post(String id, {String authorId = 'author_a'}) {
  return MomentPost(
    id: id,
    author: MomentUserSnapshot(
      id: authorId,
      name: authorId,
      avatarUrl: '',
    ),
    text: 'post $id',
    attachments: const [],
    likes: const [],
    comments: const [],
    createdAt: DateTime(2026, 6, 30),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await MomentsLocalStore.instance.clearForTest();
  });

  test('persists feed page per account scope', () async {
    await MomentsLocalStore.instance.savePage(
      ownerUserId: 'owner_a',
      scope: MomentsLocalStore.feedScope(),
      page: MomentPostPage(
        items: [_post('mom_1')],
        nextCursor: 'cursor_1',
        hasMore: true,
      ),
      replace: true,
    );

    final page = await MomentsLocalStore.instance.loadPage(
      ownerUserId: 'owner_a',
      scope: MomentsLocalStore.feedScope(),
    );

    expect(page.items.single.id, 'mom_1');
    expect(page.nextCursor, 'cursor_1');
    expect(page.hasMore, isTrue);
  });

  test('does not leak moments across account scopes', () async {
    await MomentsLocalStore.instance.savePage(
      ownerUserId: 'owner_a',
      scope: MomentsLocalStore.feedScope(),
      page: MomentPostPage(items: [_post('mom_a')], hasMore: false),
      replace: true,
    );

    final other = await MomentsLocalStore.instance.loadPage(
      ownerUserId: 'owner_b',
      scope: MomentsLocalStore.feedScope(),
    );

    expect(other.items, isEmpty);
  });

  test('skips corrupted cached payloads instead of failing page load', () async {
    await MomentsLocalStore.instance.insertRawPostForTest(
      ownerUserId: 'owner_a',
      scope: MomentsLocalStore.feedScope(),
      postId: 'broken',
      payloadJson: '{not-json',
    );

    final page = await MomentsLocalStore.instance.loadPage(
      ownerUserId: 'owner_a',
      scope: MomentsLocalStore.feedScope(),
    );

    expect(page.items, isEmpty);
  });
}
