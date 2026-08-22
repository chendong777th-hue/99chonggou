import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/moments/moment_models.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    MomentsStore.debugAccountScopeOverride = 'moments_test_a';
    MomentsStore.debugSelfSnapshotOverride = const MomentUserSnapshot(
      id: 'self_a',
      name: '我',
      avatarUrl: 'assets/default_avatar.png',
    );
  });

  tearDown(() {
    MomentsStore.debugAccountScopeOverride = null;
    MomentsStore.debugSelfSnapshotOverride = null;
  });

  test('persists draft per account scope', () async {
    await MomentsStore.saveDraft(
      MomentDraft(
        text: 'draft text',
        attachments: const [],
        updatedAt: DateTime(2026, 6, 27),
      ),
    );
    final draft = await MomentsStore.loadDraft();
    expect(draft?.text, 'draft text');

    MomentsStore.debugAccountScopeOverride = 'moments_test_b';
    expect(await MomentsStore.loadDraft(), isNull);
  });

  test('parses detail payload with likes and comments only', () {
    final post = MomentPost.fromJson(
      <String, dynamic>{
        'momentId': 'mom_1',
        'author': {
          'userId': 'self_a',
          'nickname': '我',
          'avatarUrl': 'https://cdn.example.com/avatar/self_a.jpg',
          'remark': '',
        },
        'text': 'reply test',
        'mediaList': [
          {
            'mediaId': 'media_1',
            'type': 'IMAGE',
            'url': 'https://example.com/origin.jpg',
            'thumbUrl': 'https://example.com/thumb.jpg',
            'width': 1080,
            'height': 1440,
            'durationSec': null,
            'sizeBytes': 382001,
          }
        ],
        'createdAt': 1718452800000,
        'updatedAt': 1718452800000,
        'likedByMe': true,
        'likeCount': 3,
        'likes': [
          {
            'user': {
              'userId': 'friend_like',
              'nickname': '点赞好友',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_like.jpg',
              'remark': '',
            },
            'createdAt': 1718452800000,
          }
        ],
        'commentCount': 2,
        'comments': [
          {
            'commentId': 'cmt_1',
            'author': {
              'userId': 'friend_a',
              'nickname': '好友A',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_a.jpg',
              'remark': '',
            },
            'replyToCommentId': null,
            'replyToUser': null,
            'text': 'first comment',
            'createdAt': 1718452800000,
            'canDelete': false,
          },
          {
            'commentId': 'cmt_2',
            'author': {
              'userId': 'self_a',
              'nickname': '我',
              'avatarUrl': 'https://cdn.example.com/avatar/self_a.jpg',
              'remark': '',
            },
            'replyToCommentId': 'cmt_1',
            'replyToUser': {
              'userId': 'friend_a',
              'nickname': '好友A',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_a.jpg',
              'remark': '',
            },
            'text': 'reply comment',
            'createdAt': 1718452900000,
            'canDelete': true,
          },
        ],
        'canDelete': true,
      },
    );

    final reply = post.comments.last;

    expect(post.id, 'mom_1');
    expect(post.attachments.single.mediaId, 'media_1');
    expect(
        post.attachments.single.previewPath, 'https://example.com/thumb.jpg');
    expect(post.likedBy('self_a'), isTrue);
    expect(post.likeCount, 3);
    expect(post.likes.single.author.avatarUrl,
        'https://cdn.example.com/avatar/friend_like.jpg');
    expect(post.commentCount, 2);
    expect(reply.replyToCommentId, 'cmt_1');
    expect(reply.replyToUser?.id, 'friend_a');
    expect(reply.isReply, isTrue);
  });

  test('feed payload uses likesPreview and commentsPreview only', () {
    final post = MomentPost.fromJson(
      <String, dynamic>{
        'momentId': 'mom_preview',
        'author': {
          'userId': 'self_a',
          'nickname': '我',
          'avatarUrl': 'https://cdn.example.com/avatar/self_a.jpg',
        },
        'text': 'preview test',
        'createdAt': 1718452800000,
        'likeCount': 2,
        'likesPreview': [
          {
            'user': {
              'userId': 'friend_like',
              'nickname': '点赞好友',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_like.jpg',
            },
            'createdAt': 1718452800000,
          },
        ],
        'commentCount': 1,
        'commentsPreview': [
          {
            'commentId': 'cmt_preview',
            'author': {
              'userId': 'friend_a',
              'nickname': '好友A',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_a.jpg',
            },
            'text': 'preview comment',
            'createdAt': 1718452800000,
          },
        ],
      },
    );

    expect(post.likeCount, 2);
    expect(post.likes.single.author.name, '点赞好友');
    expect(post.likes.single.author.avatarUrl,
        'https://cdn.example.com/avatar/friend_like.jpg');
    expect(post.commentCount, 1);
    expect(post.comments.single.text, 'preview comment');
  });

  test('feed payload ignores empty likes when likesPreview is present', () {
    final post = MomentPost.fromJson(
      <String, dynamic>{
        'momentId': 'mom_mixed',
        'author': {
          'userId': 'self_a',
          'nickname': '我',
          'avatarUrl': 'https://cdn.example.com/avatar/self_a.jpg',
        },
        'text': 'mixed legacy',
        'createdAt': 1718452800000,
        'likeCount': 2,
        'likes': [],
        'likesPreview': [
          {
            'user': {
              'userId': 'friend_like',
              'nickname': '点赞好友',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_like.jpg',
            },
            'createdAt': 1718452800000,
          },
        ],
      },
    );

    expect(post.likes.single.author.id, 'friend_like');
  });

  test('merge like mutation applies likesPreview onto current post', () {
    final current = MomentPost(
      id: 'mom_1',
      author: MomentUserSnapshot(
        id: 'self_a',
        name: '我',
        avatarUrl: 'https://cdn.example.com/avatar/self_a.jpg',
      ),
      text: 'hello',
      attachments: [],
      likes: [],
      comments: [],
      createdAt: _fixedTime,
      likedByMe: false,
      likeCountValue: 0,
    );

    final merged = mergeMomentLikeMutation(
      current,
      <String, dynamic>{
        'momentId': 'mom_1',
        'likedByMe': true,
        'likeCount': 1,
        'likesPreview': [
          {
            'user': {
              'userId': 'friend_like',
              'nickname': '点赞好友',
              'avatarUrl': 'https://cdn.example.com/avatar/friend_like.jpg',
            },
            'createdAt': 1718452800000,
          },
        ],
      },
    );

    expect(merged.likedByMe, isTrue);
    expect(merged.likeCount, 1);
    expect(merged.likes.single.author.avatarUrl,
        'https://cdn.example.com/avatar/friend_like.jpg');
  });

  test('parses backend notification payload', () {
    final notification = MomentNotification.fromJson(
      <String, dynamic>{
        'notificationId': 'noti_1',
        'type': 'COMMENT_REPLY',
        'actor': {
          'userId': 'friend_b',
          'nickname': '好友B',
          'avatarUrl': 'https://cdn.example.com/avatar/friend_b.jpg',
          'remark': '',
        },
        'momentId': 'mom_1',
        'momentAuthor': {
          'userId': 'self_a',
          'nickname': '我',
          'avatarUrl': 'https://cdn.example.com/avatar/self_a.jpg',
          'remark': '',
        },
        'momentText': 'notification test',
        'momentPreviewMedia': {
          'type': 'IMAGE',
          'thumbUrl': 'https://example.com/thumb.jpg',
        },
        'comment': {
          'commentId': 'cmt_2',
          'author': {
            'userId': 'friend_b',
            'nickname': '好友B',
            'avatarUrl': 'https://cdn.example.com/avatar/friend_b.jpg',
            'remark': '',
          },
          'replyToCommentId': 'cmt_1',
          'replyToUser': {
            'userId': 'friend_a',
            'nickname': '好友A',
            'avatarUrl': 'https://cdn.example.com/avatar/friend_a.jpg',
            'remark': '',
          },
          'text': 'friend reply',
          'createdAt': 1718452800000,
        },
        'replyToUser': {
          'userId': 'friend_a',
          'nickname': '好友A',
          'avatarUrl': 'https://cdn.example.com/avatar/friend_a.jpg',
          'remark': '',
        },
        'createdAt': 1718452800000,
        'read': false,
      },
    );

    expect(notification.id, 'noti_1');
    expect(notification.type, MomentNotificationType.reply);
    expect(notification.postId, 'mom_1');
    expect(notification.actor.avatarUrl,
        'https://cdn.example.com/avatar/friend_b.jpg');
    expect(notification.postPreviewPath, 'https://example.com/thumb.jpg');
    expect(notification.replyToUser?.id, 'friend_a');
  });
}

final _fixedTime = DateTime(2026, 7, 1);
