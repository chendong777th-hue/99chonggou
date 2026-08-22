import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_create_limit_api.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

void main() {
  group('GroupCreateLimitsResponse v2.0', () {
    test('parses joinGroups / communityJoinGroups / communityGroups', () {
      final limits = GroupCreateLimitsResponse.fromJson({
        'enabled': true,
        'joinGroups': {
          'max': 50,
          'used': 3,
          'remaining': 47,
          'limited': true,
        },
        'communityJoinGroups': {
          'max': 1000,
          'used': 12,
          'remaining': 988,
          'limited': true,
        },
        'communityGroups': {
          'groupType': 'Community',
          'max': 3,
          'used': 1,
          'remaining': 2,
          'limited': true,
        },
        'publicGroups': {
          'groupType': 'Public',
          'max': 5,
          'used': 5,
          'remaining': 0,
          'limited': true,
        },
      });

      expect(limits.enabled, isTrue);
      expect(limits.joinGroups?.max, 50);
      expect(limits.communityJoinGroups?.used, 12);
      expect(limits.communityGroups?.remaining, 2);
      expect(limits.infoForGroupType(GroupType.Public), isNull);
      expect(limits.infoForGroupType(GroupType.Work), isNull);
      expect(limits.infoForGroupType(GroupType.Community)?.max, 3);
      expect(limits.joinInfoForGroupType(GroupType.Public)?.max, 50);
      expect(limits.joinInfoForGroupType(GroupType.Community)?.max, 1000);
    });

    test('Work/Public create always allowed; join can block owner start', () {
      final limits = GroupCreateLimitsResponse.fromJson({
        'enabled': true,
        'joinGroups': {
          'max': 50,
          'used': 50,
          'remaining': 0,
          'limited': true,
        },
        'communityJoinGroups': {
          'max': 1000,
          'used': 0,
          'remaining': 1000,
          'limited': true,
        },
        'communityGroups': {
          'groupType': 'Community',
          'max': 3,
          'used': 0,
          'remaining': 3,
          'limited': true,
        },
      });

      expect(limits.canCreateGroupType(GroupType.Public), isTrue);
      expect(limits.canCreateGroupType(GroupType.Work), isTrue);
      expect(limits.canStartCreateAsOwner(GroupType.Public), isFalse);
      expect(limits.canStartCreateAsOwner(GroupType.Community), isTrue);
    });

    test('community create exhausted blocks start even when join remains', () {
      final limits = GroupCreateLimitsResponse.fromJson({
        'enabled': true,
        'joinGroups': {
          'max': 50,
          'used': 0,
          'remaining': 50,
          'limited': true,
        },
        'communityJoinGroups': {
          'max': 1000,
          'used': 0,
          'remaining': 1000,
          'limited': true,
        },
        'communityGroups': {
          'groupType': 'Community',
          'max': 3,
          'used': 3,
          'remaining': 0,
          'limited': true,
        },
      });

      expect(limits.canCreateGroupType(GroupType.Community), isFalse);
      expect(limits.canStartCreateAsOwner(GroupType.Community), isFalse);
    });

    test('disabled skips all limits', () {
      final limits = GroupCreateLimitsResponse.fromJson({
        'enabled': false,
        'joinGroups': {
          'max': 1,
          'used': 1,
          'remaining': 0,
          'limited': true,
        },
        'communityGroups': {
          'max': 1,
          'used': 1,
          'remaining': 0,
          'limited': true,
        },
      });
      expect(limits.canStartCreateAsOwner(GroupType.Public), isTrue);
      expect(limits.canStartCreateAsOwner(GroupType.Community), isTrue);
    });
  });
}
