import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/upload_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_payload_normalizer.dart';
import 'package:tencent_cloud_chat_demo/utils/avatar_image_warm.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

void main() {
  group('avatar response variants', () {
    test('me and user profile parse avatarVersion without changing thumb URL',
        () {
      final me = MeResult.fromJson(<String, dynamic>{
        'data': <String, dynamic>{
          'userId': 'user-1',
          'phone': '+8613800001234',
          'phoneMasked': '+86138****1234',
          'nickname': 'Alice',
          'avatarUrl': 'https://cdn.test/user-1_thumb.jpg',
          'avatarVersion': 5,
        },
      });
      final profile = UserSearchResult.fromJson(<String, dynamic>{
        'userId': 'user-1',
        'nickname': 'Alice',
        'avatarUrl': 'https://cdn.test/user-1_thumb.jpg',
        'avatar_version': '6',
      });

      expect(me.avatarUrl, 'https://cdn.test/user-1_thumb.jpg');
      expect(me.avatarVersion, 5);
      expect(profile.avatarUrl, 'https://cdn.test/user-1_thumb.jpg');
      expect(profile.avatarVersion, 6);
    });

    test('preview response models parse only explicit preview fields', () {
      final user = UserAvatarPreviewResult.fromJson(<String, dynamic>{
        'previewUrl': 'https://cdn.test/user-1_preview.jpg',
        'avatarUrl': 'https://cdn.test/user-1_thumb.jpg',
        'avatarVersion': 7,
      });
      final group = GroupAvatarPreviewResult.fromJson(<String, dynamic>{
        'preview_url': 'https://cdn.test/group-1_preview.jpg',
        'avatar_url': 'https://cdn.test/group-1_thumb.jpg',
        'avatar_version': '8',
      });

      expect(user.previewUrl, 'https://cdn.test/user-1_preview.jpg');
      expect(user.avatarVersion, 7);
      expect(group.previewUrl, 'https://cdn.test/group-1_preview.jpg');
      expect(group.avatarVersion, 8);
    });

    test('friend avatar version remains nullable', () {
      final withoutVersion = MeFriendRecord.fromJson(<String, dynamic>{
        'friendUserId': 'user-1',
        'friendAvatarUrl': 'https://cdn.test/user-1_thumb.jpg',
      });
      final withVersion = MeFriendRecord.fromJson(<String, dynamic>{
        'friendUserId': 'user-2',
        'friendAvatarUrl': 'https://cdn.test/user-2_thumb.jpg',
        'friendAvatarVersion': '9',
      });

      expect(withoutVersion.friendAvatarVersion, isNull);
      expect(withVersion.friendAvatarVersion, 9);
    });

    test('group record keeps thumb, preview, and version as separate fields',
        () {
      final group = MeGroupRecord.fromJson(<String, dynamic>{
        'groupId': 'group-1',
        'groupName': 'Group',
        'avatarUrl': 'https://cdn.test/group-1_thumb.jpg',
        'avatarPreviewUrl': 'https://cdn.test/group-1_preview.jpg',
        'avatarVersion': 10,
      });

      expect(group.avatarUrl, 'https://cdn.test/group-1_thumb.jpg');
      expect(
        group.avatarPreviewUrl,
        'https://cdn.test/group-1_preview.jpg',
      );
      expect(group.avatarVersion, 10);
    });
  });

  group('avatar upload contract', () {
    Response<dynamic> response(Map<String, dynamic> data) => Response<dynamic>(
          requestOptions: RequestOptions(path: '/me/avatar'),
          statusCode: 200,
          data: <String, dynamic>{'data': data},
        );

    test('preview-only response is rejected instead of becoming display URL',
        () {
      expect(
        () => UploadApi.instance.parseUserAvatarUploadResponse(
          response(<String, dynamic>{
            'previewUrl': 'https://cdn.test/user-1_preview.jpg',
            'originUrl': 'https://cdn.test/user-1_origin.jpg',
          }),
        ),
        throwsA(
          isA<DioError>().having(
            (error) => error.error,
            'error',
            'MISSING_THUMB_URL',
          ),
        ),
      );
    });

    test('contract-compatible avatarUrl remains the thumb display source', () {
      final result = UploadApi.instance.parseUserAvatarUploadResponse(
        response(<String, dynamic>{
          'avatarUrl': 'https://cdn.test/user-1_thumb.jpg',
          'previewUrl': 'https://cdn.test/user-1_preview.jpg',
          'originUrl': 'https://cdn.test/user-1_origin.jpg',
          'avatarVersion': 11,
        }),
      );

      expect(result.avatarUrl, 'https://cdn.test/user-1_thumb.jpg');
      expect(result.thumbUrl, 'https://cdn.test/user-1_thumb.jpg');
      expect(result.previewUrl, 'https://cdn.test/user-1_preview.jpg');
      expect(result.originUrl, 'https://cdn.test/user-1_origin.jpg');
      expect(result.avatarVersion, 11);
    });

    test('missing origin never aliases the thumb URL', () {
      final result = UploadApi.instance.parseUserAvatarUploadResponse(
        response(<String, dynamic>{
          'avatarUrl': 'https://cdn.test/user-1_thumb.jpg',
          'previewUrl': 'https://cdn.test/user-1_preview.jpg',
        }),
      );

      expect(result.originUrl, isEmpty);
    });
  });

  test('push thumb field wins over legacy avatarUrl', () {
    final normalized = PushPayloadNormalizer.normalize(<String, dynamic>{
      'avatarThumbUrl': 'https://cdn.test/user-1_thumb.jpg',
      'avatarUrl': 'https://cdn.test/user-1_preview.jpg',
    });

    expect(
      PushPayloadNormalizer.resolveAvatarUrl(normalized),
      'https://cdn.test/user-1_thumb.jpg',
    );
  });

  test('semantic cache identity includes owner, version, and variant', () {
    expect(
      UserAvatarHelper.cacheKey(
        ownerId: 'user-1',
        avatarVersion: 12,
        isGroup: false,
        variant: 'thumb',
      ),
      'avatar|user|user-1|12|thumb',
    );
    expect(
      UserAvatarHelper.cacheKey(
        ownerId: 'group-1',
        avatarVersion: 3,
        isGroup: true,
        variant: 'preview',
      ),
      'avatar|group|group-1|3|preview',
    );
    expect(
      UserAvatarHelper.cacheKey(
        ownerId: 'user-without-version',
        avatarVersion: 0,
        isGroup: false,
        variant: 'thumb',
      ),
      isNull,
    );
  });

  test('warmer and visible row can share the exact provider cache key', () {
    final warmed = AvatarImageWarm.providerFor(
      url: 'https://cdn.test/user-1_thumb.jpg',
      cacheKey: 'avatar|user|user-1|12|thumb',
      cacheSize: 108,
    );
    final visible = AvatarImageWarm.providerFor(
      url: 'https://cdn.test/user-1_thumb.jpg',
      cacheKey: 'avatar|user|user-1|12|thumb',
      cacheSize: 108,
    );

    expect(warmed, visible);
    expect(warmed.hashCode, visible.hashCode);
  });

  test('decoded avatar provider identity changes with target pixel size', () {
    final compact = AvatarImageWarm.providerFor(
      url: 'https://cdn.test/user-1_thumb.jpg',
      cacheKey: 'avatar|user|user-1|12|thumb',
      cacheSize: 80,
    );
    final conversationRow = AvatarImageWarm.providerFor(
      url: 'https://cdn.test/user-1_thumb.jpg',
      cacheKey: 'avatar|user|user-1|12|thumb',
      cacheSize: 162,
    );

    expect(compact, isNot(conversationRow));
  });
}
