import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 群操作灰字 Custom（App sendMessage，全员可见）。
const String kGroupTipBusinessID = 'group_tip';

const Set<String> kGroupTipActions = <String>{
  'member_added',
  'member_removed',
  'member_left',
  'member_muted',
  'member_unmuted',
  'group_mute_all_on',
  'group_mute_all_off',
  'member_set_admin',
  'member_cancel_admin',
  'group_name_changed',
  'group_avatar_changed',
  'group_notice_changed',
  'owner_changed',
  'group_apply_join_option_changed',
  'group_invite_join_option_changed',
  'group_qr_join_enabled',
  'group_qr_join_disabled',
  'group_alias_join_enabled',
  'group_alias_join_disabled',
  'group_privacy_enabled',
  'group_privacy_disabled',
};

/// join-options 变更产生的 tip 描述（action + detail）。
class GroupJoinOptionsTipSpec {
  const GroupJoinOptionsTipSpec({
    required this.action,
    required this.detail,
  });

  final String action;
  final Map<String, dynamic> detail;
}

String groupJoinOptionTipLabel(Object? raw) {
  switch (GroupJoinOption.fromStorage(raw?.toString())) {
    case GroupJoinOption.freeAccess:
      return '自动审批';
    case GroupJoinOption.needPermission:
      return '管理员审批';
    case GroupJoinOption.disabled:
      return '禁止';
  }
}

/// 对比 before/after，只对变化字段产出 tip（通常 0～1 条）。
List<GroupJoinOptionsTipSpec> groupJoinOptionsTipDiffs(
  GroupJoinOptions before,
  GroupJoinOptions after,
) {
  final specs = <GroupJoinOptionsTipSpec>[];
  if (before.applyJoinOption != after.applyJoinOption) {
    specs.add(
      GroupJoinOptionsTipSpec(
        action: 'group_apply_join_option_changed',
        detail: <String, dynamic>{
          'applyJoinOption': after.applyJoinOption.storageValue,
        },
      ),
    );
  }
  if (before.inviteJoinOption != after.inviteJoinOption) {
    specs.add(
      GroupJoinOptionsTipSpec(
        action: 'group_invite_join_option_changed',
        detail: <String, dynamic>{
          'inviteJoinOption': after.inviteJoinOption.storageValue,
        },
      ),
    );
  }
  if (before.allowJoinByQrCode != after.allowJoinByQrCode) {
    specs.add(
      GroupJoinOptionsTipSpec(
        action: after.allowJoinByQrCode
            ? 'group_qr_join_enabled'
            : 'group_qr_join_disabled',
        detail: <String, dynamic>{
          'allowJoinByQrCode': after.allowJoinByQrCode,
        },
      ),
    );
  }
  if (before.allowJoinByAlias != after.allowJoinByAlias) {
    specs.add(
      GroupJoinOptionsTipSpec(
        action: after.allowJoinByAlias
            ? 'group_alias_join_enabled'
            : 'group_alias_join_disabled',
        detail: <String, dynamic>{
          'allowJoinByAlias': after.allowJoinByAlias,
        },
      ),
    );
  }
  return specs;
}

Map<String, dynamic>? parseGroupTipPayload(V2TimCustomElem? customElem) {
  if (customElem == null) {
    return null;
  }
  final raw = customElem.data?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(decoded);
    if (map['businessID']?.toString() != kGroupTipBusinessID) {
      return null;
    }
    final action = map['action']?.toString().trim().toLowerCase() ?? '';
    if (!kGroupTipActions.contains(action)) {
      return null;
    }
    return map;
  } catch (_) {
    return null;
  }
}

bool isGroupTipCustomMessage(V2TimMessage message) {
  if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
    return false;
  }
  return parseGroupTipPayload(message.customElem) != null;
}

String? groupTipActionOf(V2TimMessage message) {
  final map = parseGroupTipPayload(message.customElem);
  return map?['action']?.toString().trim().toLowerCase();
}

/// 是否为会改会话列表群名/头像的 tip（Entity 展示字段）。
bool isGroupDisplayTipAction(String? action) {
  final normalized = action?.trim().toLowerCase() ?? '';
  return normalized == 'group_name_changed' ||
      normalized == 'group_avatar_changed';
}

/// 拉人/踢人/退群 tip：用于 TCP 丢包时的成员人数/名单备份同步。
bool isGroupMembershipTipAction(String? action) {
  final normalized = action?.trim().toLowerCase() ?? '';
  return normalized == 'member_added' ||
      normalized == 'member_removed' ||
      normalized == 'member_left';
}

/// 从 tip payload 抽出群展示字段（detail 优先，兼容常见别名）。
({String groupName, String avatarUrl}) extractGroupTipDisplayFields(
  Map<String, dynamic> map,
) {
  final detail = map['detail'] is Map
      ? Map<String, dynamic>.from(map['detail'] as Map)
      : const <String, dynamic>{};
  String read(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = source[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  final groupName = read(detail, const ['groupName', 'group_name', 'name']);
  final avatarUrl = read(detail, const [
    'avatarUrl',
    'avatar_url',
    'groupFaceUrl',
    'group_face_url',
    'faceUrl',
    'face_url',
    'thumbUrl',
    'thumb_url',
  ]);
  return (groupName: groupName, avatarUrl: avatarUrl);
}

List<String> groupTipMemberUserIds(Map<String, dynamic> map) {
  final raw = map['memberUserIds'];
  if (raw is! List) {
    return const <String>[];
  }
  return raw
      .map((item) => ChatIdFormat.rawUserUid(item?.toString() ?? ''))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

/// 展示文案：优先 payload.previewAbstract，否则按 action 拼装。
String groupTipDisplayText(Map<String, dynamic> map) {
  final preview = map['previewAbstract']?.toString().trim() ?? '';
  if (preview.isNotEmpty) {
    return preview;
  }
  final opName = (map['opUserName']?.toString().trim().isNotEmpty == true)
      ? map['opUserName'].toString().trim()
      : (map['opUserId']?.toString().trim() ?? '');
  final names = <String>[];
  final memberNames = map['memberNames'];
  if (memberNames is List) {
    for (final item in memberNames) {
      final name = item?.toString().trim() ?? '';
      if (name.isNotEmpty) {
        names.add(name);
      }
    }
  }
  if (names.isEmpty) {
    for (final id in groupTipMemberUserIds(map)) {
      names.add(id);
    }
  }
  final members = names.join('、');
  final action = map['action']?.toString().trim().toLowerCase() ?? '';
  final detail = map['detail'] is Map
      ? Map<String, dynamic>.from(map['detail'] as Map)
      : const <String, dynamic>{};
  switch (action) {
    case 'member_added':
      return '$opName邀请$members加入群组';
    case 'member_removed':
      return '$opName将$members踢出群组';
    case 'member_left':
      final leaver = members.isNotEmpty ? members : opName;
      return '$leaver退出群聊';
    case 'member_muted':
      return '$opName将$members禁言';
    case 'member_unmuted':
      return '$opName解除了$members的禁言';
    case 'group_mute_all_on':
      return '$opName开启了全员禁言';
    case 'group_mute_all_off':
      return '$opName关闭了全员禁言';
    case 'member_set_admin':
      return '$opName将$members设置为管理员';
    case 'member_cancel_admin':
      return '$opName将$members取消管理员';
    case 'group_name_changed':
      return '$opName修改了群名称';
    case 'group_avatar_changed':
      return '$opName修改了群头像';
    case 'group_notice_changed':
      return '$opName修改了群公告';
    case 'owner_changed':
      return '$opName将群主转让给$members';
    case 'group_apply_join_option_changed':
      return '$opName将申请加群方式修改为${groupJoinOptionTipLabel(detail['applyJoinOption'] ?? detail['apply_join_option'])}';
    case 'group_invite_join_option_changed':
      return '$opName将邀请好友方式修改为${groupJoinOptionTipLabel(detail['inviteJoinOption'] ?? detail['invite_join_option'])}';
    case 'group_qr_join_enabled':
      return '$opName开启了二维码加群';
    case 'group_qr_join_disabled':
      return '$opName关闭了二维码加群';
    case 'group_alias_join_enabled':
      return '$opName开启了群别名加群';
    case 'group_alias_join_disabled':
      return '$opName关闭了群别名加群';
    case 'group_privacy_enabled':
      return '$opName开启了群成员隐私保护';
    case 'group_privacy_disabled':
      return '$opName关闭了群成员隐私保护';
    default:
      return '群提示';
  }
}

String buildGroupTipPreviewAbstract({
  required String action,
  required String opUserName,
  List<String> memberNames = const <String>[],
  Map<String, dynamic>? detail,
}) {
  return groupTipDisplayText(<String, dynamic>{
    'action': action,
    'opUserName': opUserName,
    'memberNames': memberNames,
    if (detail != null && detail.isNotEmpty) 'detail': detail,
  });
}

Map<String, dynamic> buildGroupTipPayload({
  required String action,
  required String opUserId,
  required String opUserName,
  required String clientMsgId,
  List<String> memberUserIds = const <String>[],
  List<String> memberNames = const <String>[],
  Map<String, dynamic>? detail,
  String? previewAbstract,
}) {
  final normalizedAction = action.trim().toLowerCase();
  final preview = (previewAbstract != null && previewAbstract.trim().isNotEmpty)
      ? previewAbstract.trim()
      : buildGroupTipPreviewAbstract(
          action: normalizedAction,
          opUserName: opUserName,
          memberNames: memberNames,
          detail: detail,
        );
  return <String, dynamic>{
    'businessID': kGroupTipBusinessID,
    'version': 1,
    'action': normalizedAction,
    'opUserId': ChatIdFormat.rawUserUid(opUserId),
    'opUserName': opUserName.trim(),
    'memberUserIds': memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList(growable: false),
    'memberNames': memberNames
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false),
    'previewAbstract': preview,
    'clientMsgId': clientMsgId.trim(),
    if (detail != null && detail.isNotEmpty) 'detail': detail,
  };
}
