import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_quota_limit_error.dart';
import 'package:tencent_cloud_chat_demo/utils/group_create_limit_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_invite_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

void main() {
  group('GroupQuotaLimitError.tryParse', () {
    test('parses overLimitUsers', () {
      final err = GroupQuotaLimitError.tryParse({
        'code': 'GROUP_JOIN_LIMIT_EXCEEDED',
        'message': '部分用户加入群数量已达上限',
        'overLimitUsers': [
          {
            'userId': 'u1',
            'used': 50,
            'max': 50,
            'limitType': 'join',
          },
        ],
      });
      expect(err, isNotNull);
      expect(err!.isJoinLimit, isTrue);
      expect(err.overLimitUsers.single.userId, 'u1');
      expect(err.overLimitUsers.single.limitType, 'join');
    });
  });

  group('GroupCreateLimitMessage.fromApiCode', () {
    test('maps join and create codes', () {
      final joinPublic = GroupCreateLimitMessage.fromApiCode(
        code: 'GROUP_JOIN_LIMIT_EXCEEDED',
        groupType: GroupType.Public,
      )!;
      expect(
        joinPublic.contains('普通群') ||
            joinPublic.toLowerCase().contains('standard group'),
        isTrue,
      );
      final joinCommunity = GroupCreateLimitMessage.fromApiCode(
        code: 'GROUP_JOIN_LIMIT_COMMUNITY',
        groupType: GroupType.Public,
      )!;
      expect(
        joinCommunity.contains('超级大群') ||
            joinCommunity.toLowerCase().contains('super group'),
        isTrue,
      );
      final createCommunity = GroupCreateLimitMessage.fromApiCode(
        code: 'GROUP_CREATE_LIMIT_COMMUNITY',
        groupType: GroupType.Community,
      )!;
      expect(
        createCommunity.contains('创建') ||
            createCommunity.toLowerCase().contains('creation'),
        isTrue,
      );
    });
  });

  group('GroupCreateLimitMessage.fromQuotaError', () {
    test('uses overLimitUsers join list message for others', () {
      final err = GroupQuotaLimitError(
        code: 'GROUP_JOIN_LIMIT_EXCEEDED',
        overLimitUsers: const [
          GroupOverLimitUser(
            userId: 'other',
            used: 50,
            max: 50,
            limitType: 'join',
          ),
        ],
      );
      final text = GroupCreateLimitMessage.fromQuotaError(
        err,
        selfUserId: 'me',
      )!;
      expect(
        text.contains('部分用户') || text.toLowerCase().contains('some users'),
        isTrue,
      );
    });
  });

  group('GroupInviteMessage limit ordering', () {
    test('GROUP_JOIN_LIMIT is not mapped to member capacity', () {
      final text = GroupInviteMessage.fromResult(
        code: -1,
        desc: 'GROUP_JOIN_LIMIT',
      );
      expect(text.contains('群成员已达上限'), isFalse);
      expect(text.toLowerCase().contains('group member limit'), isFalse);
      expect(
        text.contains('普通群') || text.toLowerCase().contains('standard group'),
        isTrue,
      );
    });

    test('generic LIMIT still maps to member capacity', () {
      final text = GroupInviteMessage.fromResult(
        code: -1,
        desc: 'MEMBER_LIMIT',
      );
      expect(
        text.contains('群成员已达上限') ||
            text.toLowerCase().contains('group member limit'),
        isTrue,
      );
    });
  });
}
