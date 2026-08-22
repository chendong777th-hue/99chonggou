import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

void main() {
  group('user profile open avatar stability', () {
    test('loadData sync-seeds from readCached before first await', () {
      final source = File(
        'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart',
      ).readAsStringSync();
      final loadDataStart = source.indexOf(
        'loadData({required String userID, bool isNeedConversation = true}) async {',
      );
      expect(loadDataStart, greaterThanOrEqualTo(0));
      final nextMethod = source.indexOf('\n  Future<', loadDataStart + 1);
      final body = source.substring(
        loadDataStart,
        nextMethod > loadDataStart ? nextMethod : source.length,
      );

      final readCachedAt = body.indexOf('readCached(');
      final firstAwaitAt = body.indexOf('await ');
      expect(readCachedAt, greaterThanOrEqualTo(0));
      expect(firstAwaitAt, greaterThanOrEqualTo(0));
      expect(
        readCachedAt,
        lessThan(firstAwaitAt),
        reason: 'readCached seed must run before any await in loadData',
      );
      expect(body.contains('notifyListeners();'), isTrue);
    });

    test('Avatar uses neutral placeholder for real network faceUrl', () {
      final source = File(
        'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/avatar.dart',
      ).readAsStringSync();
      expect(source.contains('placeholderForFaceUrl'), isTrue);
      expect(
        source.contains(
          'placeholder: (context, url) => placeholderForFaceUrl(url)',
        ),
        isTrue,
      );
      expect(
        source.contains('placeholder: (context, url) => defaultAvatar()'),
        isFalse,
      );
      expect(source.contains('ColoredBox'), isTrue);
    });

    test('applyBackendProfile gates avatar with shouldReplaceProfileFaceUrl',
        () {
      final source = File('lib/src/user_profile.dart').readAsStringSync();
      expect(source.contains('shouldReplaceProfileFaceUrl'), isTrue);
      expect(
        source.contains('UserAvatarHelper.shouldReplaceProfileFaceUrl'),
        isTrue,
      );
    });

    group('UserAvatarHelper.shouldReplaceProfileFaceUrl', () {
      test('empty current + usable incoming → replace', () {
        expect(
          UserAvatarHelper.shouldReplaceProfileFaceUrl(
            current: '',
            incoming: 'https://cdn.example/a.png',
          ),
          isTrue,
        );
      });

      test('usable current + empty incoming → keep', () {
        expect(
          UserAvatarHelper.shouldReplaceProfileFaceUrl(
            current: 'https://cdn.example/a.png',
            incoming: '',
          ),
          isFalse,
        );
      });

      test('usable current + different usable incoming → keep (fill-only)', () {
        expect(
          UserAvatarHelper.shouldReplaceProfileFaceUrl(
            current: 'https://cdn.example/a.png',
            incoming: 'https://cdn.example/b.png',
          ),
          isFalse,
        );
      });

      test('usable current + same incoming → keep (no-op write)', () {
        expect(
          UserAvatarHelper.shouldReplaceProfileFaceUrl(
            current: 'https://cdn.example/a.png',
            incoming: 'https://cdn.example/a.png',
          ),
          isFalse,
        );
      });

      test('default-placeholder current + usable incoming → replace', () {
        expect(
          UserAvatarHelper.shouldReplaceProfileFaceUrl(
            current: 'https://cdn.example/default_c2c_head.png',
            incoming: 'https://cdn.example/a.png',
          ),
          isTrue,
        );
      });
    });
  });
}
