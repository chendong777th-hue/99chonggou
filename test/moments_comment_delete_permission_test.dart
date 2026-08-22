import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';

MomentComment _comment({
  required String authorId,
  bool canDelete = false,
}) {
  return MomentComment(
    id: 'cmt_1',
    author: MomentUserSnapshot(
      id: authorId,
      name: 'user',
      avatarUrl: '',
    ),
    text: 'hello',
    createdAt: DateTime(2026, 7, 10),
    canDelete: canDelete,
  );
}

void main() {
  test('comment author can delete own comment on others post', () {
    final comment = _comment(authorId: 'me');
    expect(
      comment.canBeDeletedBy(selfId: 'me', isPostOwner: false),
      isTrue,
    );
  });

  test('post owner can delete others comment', () {
    final comment = _comment(authorId: 'other');
    expect(
      comment.canBeDeletedBy(selfId: 'me', isPostOwner: true),
      isTrue,
    );
  });

  test('stranger cannot delete comment', () {
    final comment = _comment(authorId: 'other');
    expect(
      comment.canBeDeletedBy(selfId: 'me', isPostOwner: false),
      isFalse,
    );
  });

  test('backend canDelete overrides local identity check', () {
    final comment = _comment(authorId: 'other', canDelete: true);
    expect(
      comment.canBeDeletedBy(selfId: 'me', isPostOwner: false),
      isTrue,
    );
  });

  test('empty selfId cannot delete without backend flag', () {
    final comment = _comment(authorId: 'me');
    expect(
      comment.canBeDeletedBy(selfId: '', isPostOwner: true),
      isFalse,
    );
  });
}
