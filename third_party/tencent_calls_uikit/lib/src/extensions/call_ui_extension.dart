import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/ui/widget/joiningroup/join_in_group_widget.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_uikit_core/tencent_cloud_uikit_core.dart';

class CallUIExtension extends AbstractTUIExtension {
  static final CallUIExtension _instance = CallUIExtension();

  static CallUIExtension get instance => _instance;

  @override
  Future<Widget> onRaiseExtension(
    TUIExtensionID extensionID,
    Map<String, dynamic> param,
  ) {
    if (extensionID == TUIExtensionID.joinInGroup) {
      return _getGroupAttributes(param);
    }

    return Future<Widget>.value(const SizedBox());
  }

  Future<Widget> _getGroupAttributes(Map<String, dynamic> param) async {
    final groupId = (param[GROUP_ID] as String?)?.trim() ?? '';
    if (groupId.isEmpty) {
      return const SizedBox();
    }

    final resultMap = await TencentImSDKPlugin.v2TIMManager.v2TIMGroupManager
        .getGroupAttributes(groupID: groupId);
    if (resultMap.code != 0 || resultMap.data == null) {
      return const SizedBox();
    }

    final raw = resultMap.data!['inner_attr_kit_info'];
    if (raw == null) {
      return const SizedBox();
    }
    final groupAttAryString = raw is String ? raw : raw.toString();
    if (groupAttAryString.isEmpty) {
      return const SizedBox();
    }

    final Map<String, dynamic> groupAttAryMap;
    try {
      final decoded = jsonDecode(groupAttAryString);
      if (decoded is! Map) {
        return const SizedBox();
      }
      groupAttAryMap = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return const SizedBox();
    }

    final callId = groupAttAryMap['call_id']?.toString();
    final businessType = groupAttAryMap['business_type']?.toString();
    final roomIDValue = groupAttAryMap['room_id']?.toString();
    final roomIDType = groupAttAryMap['room_id_type'];
    final mediaTypeString = groupAttAryMap['call_media_type']?.toString() ?? '';

    final rawUserList = groupAttAryMap['user_list'];
    if (rawUserList is! List) {
      return const SizedBox();
    }

    TUIRoomId? roomId;
    if (roomIDType != null && roomIDValue != null && roomIDValue.isNotEmpty) {
      if (roomIDType == 1 || roomIDType == 0) {
        final parsed = int.tryParse(roomIDValue);
        if (parsed == null) {
          return const SizedBox();
        }
        roomId = TUIRoomId.intRoomId(intRoomId: parsed);
      } else {
        roomId = TUIRoomId.strRoomId(strRoomId: roomIDValue);
      }
    }

    final TUICallMediaType mediaType =
        mediaTypeString == 'audio' ? TUICallMediaType.audio : TUICallMediaType.video;

    final userIds = <String>[];
    for (final user in rawUserList) {
      if (user is! Map) {
        continue;
      }
      final userId = user['userid']?.toString().trim();
      if (userId != null && userId.isNotEmpty) {
        userIds.add(userId);
      }
    }

    if (businessType != 'callkit' ||
        userIds.length <= 1 ||
        mediaTypeString.isEmpty ||
        roomId == null) {
      return const SizedBox();
    }

    return JoinInGroupWidget(
      userIDs: userIds,
      roomId: roomId,
      mediaType: mediaType,
      groupId: groupId,
      callId: callId,
    );
  }
}
