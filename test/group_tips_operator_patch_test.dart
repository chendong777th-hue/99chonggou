import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tips_operator_patch_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_live_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tips_operator_patch_metadata.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';

void main() {
  setUp(() {
    GroupTipsOperatorLiveCache.instance.clear();
  });

  test('live cache upsert bumps revision and stores preview', () {
    final cache = GroupTipsOperatorLiveCache.instance;
    final before = cache.revision.value;
    cache.upsert(
      const GroupTipsOperatorLiveEntry(
        changeEventId: 'ce_live_1',
        groupId: 'group_demo',
        action: 'member_added',
        operatorUserId: 'user_a',
        memberUserIds: <String>['user_b'],
        occurredAtSec: 1700000000,
        previewAbstract: '算账号邀请过眼云烟加入群组',
      ),
    );
    expect(cache.revision.value, greaterThan(before));
  });

  test('mergePatch stores preview and operator', () {
    final raw = GroupTipsOperatorPatchMetadata.mergePatch(
      existingRaw: null,
      changeEventId: 'ce_01',
      resolvedOperatorUserId: 'user_a',
      previewAbstract: '算账号邀请过眼云烟加入群组',
      action: 'member_added',
      timelineRank: 30,
    );
    final data = GroupTipsOperatorPatchMetadata.readMap(raw);
    expect(data, isNotNull);
    expect(GroupTipsOperatorPatchMetadata.isOperatorPatch(data!), isTrue);
    expect(GroupTipsOperatorPatchMetadata.changeEventId(data), 'ce_01');
    expect(
      GroupTipsOperatorPatchMetadata.resolvedOperatorUserId(data),
      'user_a',
    );
    expect(
      GroupTipsOperatorPatchMetadata.previewAbstract(data),
      '算账号邀请过眼云烟加入群组',
    );
  });

  test('mergePatch preserves existing localCustomData keys', () {
    final raw = GroupTipsOperatorPatchMetadata.mergePatch(
      existingRaw: '{"timelineRank":20,"outgoingLocalSeq":3}',
      changeEventId: 'ce_02',
      resolvedOperatorUserId: 'user_b',
      previewAbstract: '毛毛邀请 user_c 加入群组',
      action: 'member_added',
      timelineRank: 30,
    );
    final data = GroupTipsOperatorPatchMetadata.readMap(raw);
    expect(data?['outgoingLocalSeq'], 3);
    expect(data?['timelineRank'], 30);
  });

  test('mergeSuppressFlag marks administrator duplicate tips hidden', () {
    final raw = GroupTipsOperatorPatchMetadata.mergeSuppressFlag(
      existingRaw: '{"previewAbstract":"管理员邀请 user_b 加入群组"}',
    );
    final data = GroupTipsOperatorPatchMetadata.readMap(raw);
    expect(GroupTipsOperatorPatchMetadata.isSuppressed(data!), isTrue);
  });

  test('groupTipsMessageListsSharePatchState compares patch fields cheaply', () {
    V2TimMessage msg(String id, String data) {
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = id;
      message.localCustomData = data;
      return message;
    }

    final shared = msg('m1', '{"a":1}');
    final before = <V2TimMessage>[
      shared,
      msg('m2', '{"b":2}'),
    ];
    final afterSame = <V2TimMessage>[
      shared,
      msg('m2', '{"b":2}'),
    ];
    final afterChanged = <V2TimMessage>[
      shared,
      msg('m2', '{"b":2,"suppressAdministratorGroupTip":true}'),
    ];
    expect(groupTipsMessageListsSharePatchState(before, afterSame), isTrue);
    expect(groupTipsMessageListsSharePatchState(before, afterChanged), isFalse);
    expect(groupTipsMessageListsSharePatchState(before, before), isTrue);
  });

  test('actionForTipsType maps member actions', () {
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE,
      ),
      'member_added',
    );
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED,
      ),
      'member_removed',
    );
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT,
      ),
      'member_left',
    );
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN,
      ),
      'member_set_admin',
    );
    expect(
      GroupTipsMessageHelper.actionForTipsType(
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN,
      ),
      'member_cancel_admin',
    );
  });
}
