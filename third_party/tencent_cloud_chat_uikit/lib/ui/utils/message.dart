// ignore_for_file: unrelated_type_equality_checks, avoid_print

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_change_info_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_tips_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_tips_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_tips_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/time.dart';
import 'package:collection/collection.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

class MessageUtils {
  // 判断CallingData的方式和Trtc的方法一致
  static isCallingData(String data) {
    try {
      Map<String, dynamic> customMap = jsonDecode(data);

      if (customMap.containsKey('businessID') && customMap['businessID'] == 1) {
        return true;
      }
    } catch (e) {
      outputLogger.i("isCallingData json parse error");
      return false;
    }
    return false;
  }

  static bool? isC2CCallOutgoing(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return null;
    }

    final rawData = message.customElem?.data;
    if (rawData == null || rawData.isEmpty) {
      return null;
    }

    try {
      final customMap = jsonDecode(rawData);
      if (customMap is! Map) {
        return null;
      }

      final decodedData = _decodeCallingPayload(customMap);
      if (decodedData == null) {
        return null;
      }

      final businessID = decodedData['businessID']?.toString().trim().toLowerCase();
      // LiveKit cutover still uses lk_call on the wire; bubble layer may
      // normalize to av_call. Accept both for direction / avatar routing.
      if (businessID != 'av_call' &&
          businessID != 'rtc_call' &&
          businessID != 'lk_call') {
        final raw = rawData.toLowerCase();
        if (!raw.contains('lk_call') &&
            !raw.contains('av_call') &&
            !raw.contains('rtc_call')) {
          return null;
        }
      }

      final groupID = _readString(customMap['groupID']) ?? _readString(decodedData['groupID']);
      if (groupID != null && groupID.isNotEmpty) {
        return null;
      }

      final isExcludedFromHistory =
          (message.isExcludedFromLastMessage ?? false) && (message.isExcludedFromUnreadCount ?? false);
      if (isExcludedFromHistory) {
        return null;
      }

      // C2C 通话方向的唯一权威来源是 App 层 provider.direction（经
      // renderingDirectionCallback 上屏），此处禁用 message.isSelf 兜底，
      // 只从 App 写入的 callDirection 标记读取方向，避免与气泡左右不一致。
      // 返回值本身仅用于“是否通话气泡”的判定，不参与对齐/头像计算。
      final markedDirection = _readCallDirectionMarker(message);
      if (markedDirection != null) {
        return markedDirection;
      }
      return true;
    } catch (e) {
      outputLogger.i("isC2CCallOutgoing json parse error");
      return null;
    }
  }

  /// 读取 App 层写入 localCustomData 的 callDirection 标记（outgoing/incoming）。
  /// 找不到标记时返回 null，交由上层默认逻辑处理（不再回退到 isSelf）。
  static bool? _readCallDirectionMarker(V2TimMessage message) {
    final raw = message.localCustomData;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final direction = _readString(decoded['callDirection'])?.trim();
      if (direction == 'outgoing') {
        return true;
      }
      if (direction == 'incoming') {
        return false;
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _decodeCallingPayload(Map customMap) {
    final nested = customMap['data'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    if (nested is String && nested.isNotEmpty) {
      final decoded = jsonDecode(nested);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    }
    return null;
  }

  static String? _readString(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  // 是否是群组TRTC信息
  static isGroupCallingMessage(V2TimMessage message) {
    final isGroup = message.groupID != null;
    final isCustomMessage = message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
    if (isCustomMessage) {
      final customElemData = message.customElem?.data ?? "";
      return isCallingData(customElemData) && isGroup;
    }
    return false;
  }

  static String getCustomGroupCreatedOrDismissedString(V2TimMessage message) {
    try {
      final isGroup = message.groupID != null;
      final isCustomMessage = message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
      if (isCustomMessage && isGroup) {
        final data = message.customElem?.data ?? "";
        Map<String, dynamic> customMap = jsonDecode(data);
        if (customMap.containsKey('businessID') && customMap['businessID'] == "group_create") {
          final content = "${customMap['opUser']}${customMap['content']}";
          return content;
        }
        return "";
      }
      return "";
    } catch (e) {
      outputLogger.i("getCustomGroupCreatedOrDismissedString json parse error");
      return "";
    }
  }

  static bool _isNetworkUrl(String? raw) {
    final v = raw?.trim() ?? '';
    return v.startsWith('http://') || v.startsWith('https://');
  }

  /// 群资料变更提示中的新群头像 URL（仅修改群头像时有值）。
  static String? groupTipsGroupFaceUrl(V2TimGroupTipsElem groupTipsElem) {
    if (groupTipsElem.type !=
        GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE) {
      return null;
    }
    final list = groupTipsElem.groupChangeInfoList ?? [];
    for (final item in list) {
      if (item == null) continue;
      if (item.type == GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_FACE_URL) {
        final url = item.value?.trim() ?? '';
        if (_isNetworkUrl(url)) {
          return url;
        }
      }
    }
    return null;
  }

  static Future<String> _getGroupChangeType(
      V2TimGroupChangeInfo info, List<V2TimGroupMemberFullInfo?> groupMemberList) async {
    int? type = info.type;
    var value = info.value;
    String s = TIM_t('群资料信息');
    switch (type) {
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_CUSTOM:
        s = TIM_t("自定义字段");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_FACE_URL:
        s = TIM_t("群头像");
        if (_isNetworkUrl(value)) {
          final String option8 = s;
          return TIM_t_para("{{option8}}为 ", "$option8为 ")(option8: option8);
        }
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_INTRODUCTION:
        s = TIM_t("群简介");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NAME:
        s = TIM_t("群名称");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_NOTIFICATION:
        s = TIM_t("群公告");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_OWNER:
        s = TIM_t("群主");
        final V2TimGroupMemberFullInfo? groupMemberInfo =
            groupMemberList.firstWhereOrNull((element) => element?.userID == value);
        if (groupMemberInfo != null) {
          value = TencentUtils.checkString(groupMemberInfo.friendRemark) ??
              TencentUtils.checkString(groupMemberInfo.nameCard) ??
              TencentUtils.checkString(groupMemberInfo.nickName) ??
              TencentUtils.checkString(groupMemberInfo.userID);
        } else {
          final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(userIDList: [value ?? ""]);
          if (res.code == 0) {
            final List<V2TimUserFullInfo> data = res.data ?? [];
            if (data.isNotEmpty) {
              final firstPerson = data[0];
              value = TencentUtils.checkString(firstPerson.nickName) ?? TencentUtils.checkString(firstPerson.userID);
            }
          }
        }
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_SHUT_UP_ALL:
        s = TIM_t("全员禁言状态");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_RECEIVE_MESSAGE_OPT:
        s = TIM_t("消息接收方式");
        break;
      case GroupChangeInfoType.V2TIM_GROUP_INFO_CHANGE_TYPE_GROUP_ADD_OPT:
        s = TIM_t("加群方式");
        break;
    }

    final String option8 = s;
    if (value != null && value.isNotEmpty) {
      return TIM_t_para("{{option8}}为 ", "$option8为 ")(option8: option8) + value;
    } else {
      return option8;
    }
  }

  static bool _isRolePlaceholderNick(String? name) {
    final lower = (name ?? '').trim().toLowerCase();
    return lower == 'administrator' || lower == 'admin';
  }

  static String? _normalizeGroupOpDisplayName(String? name) {
    if (_isRolePlaceholderNick(name)) {
      return TIM_t('管理员');
    }
    return name;
  }

  static String? _getOpUserNick(
    V2TimGroupMemberInfo? opUser, {
    List<V2TimGroupMemberFullInfo?>? groupMemberList,
    V2TimMessage? message,
  }) {
    if (opUser == null) {
      return "";
    }
    final patchedOperator = message == null
        ? null
        : GroupTipsMessageHelper.resolvedMemberTipOperatorUserId(message);
    if (patchedOperator != null && patchedOperator.isNotEmpty) {
      if (groupMemberList != null) {
        final member = groupMemberList.firstWhereOrNull(
          (element) =>
              element != null && element.userID.trim() == patchedOperator,
        );
        if (member != null) {
          final resolved = TencentUtils.checkString(member.friendRemark) ??
              TencentUtils.checkString(member.nameCard) ??
              TencentUtils.checkString(member.nickName) ??
              TencentUtils.checkString(member.userID);
          if (resolved != null && !_isRolePlaceholderNick(resolved)) {
            return resolved;
          }
        }
      }
      if (!_isRolePlaceholderNick(patchedOperator)) {
        return patchedOperator;
      }
    }
    final resolved = TencentUtils.checkString(opUser.nameCard) ??
        TencentUtils.checkString(opUser.nickName) ??
        TencentUtils.checkString(opUser.userID);
    return _normalizeGroupOpDisplayName(resolved);
  }

  static String? _getMemberNickName(
    V2TimGroupMemberInfo e, {
    List<V2TimGroupMemberFullInfo?>? groupMemberList,
  }) {
    final userId = e.userID?.trim() ?? '';
    if (userId.isNotEmpty && groupMemberList != null) {
      final member = groupMemberList.firstWhereOrNull(
        (element) => element != null && element.userID.trim() == userId,
      );
      if (member != null) {
        final resolved = TencentUtils.checkString(member.friendRemark) ??
            TencentUtils.checkString(member.nameCard) ??
            TencentUtils.checkString(member.nickName) ??
            TencentUtils.checkString(member.userID);
        if (resolved != null && !_isRolePlaceholderNick(resolved)) {
          return resolved;
        }
      }
    }
    final friendRemark = e.friendRemark;
    final nameCard = e.nameCard;
    final nickName = e.nickName;
    final userID = e.userID;

    if (friendRemark != null && friendRemark != "") {
      return friendRemark;
    } else if (nameCard != null && nameCard != "") {
      return nameCard;
    } else if (nickName != null && nickName != "") {
      return nickName;
    } else {
      return userID;
    }
  }

  static Future<String> groupTipsMessageAbstract(
    V2TimGroupTipsElem groupTipsElem,
    List<V2TimGroupMemberFullInfo?> groupMemberList, {
    V2TimMessage? message,
  }) async {
    if (message != null) {
      final resolved = GroupTipsMessageHelper.resolvedMemberTipPreview(message);
      if (resolved != null && resolved.trim().isNotEmpty) {
        return resolved;
      }
      if (GroupTipsMessageHelper.isPendingAdministratorMemberTip(message)) {
        return '';
      }
    }
    String displayMessage;
    final operationType = groupTipsElem.type;
    final operationMember = groupTipsElem.opMember;
    final memberList = groupTipsElem.memberList;
    final opUserNickName = _getOpUserNick(
      operationMember,
      groupMemberList: groupMemberList,
      message: message,
    );
    switch (operationType) {
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_GROUP_INFO_CHANGE:
        final String? option7 = opUserNickName ?? "";
        final groupChangeInfoList = groupTipsElem.groupChangeInfoList ?? [];
        String changedInfoString = "";
        bool changedValue = false;
        for (V2TimGroupChangeInfo? element in groupChangeInfoList) {
          final newText = await _getGroupChangeType(element!, groupMemberList);
          changedInfoString += (changedInfoString.isEmpty ? "" : " / ") + newText;
          changedValue = element.boolValue ?? false;
        }
        if (changedInfoString.isEmpty) {
          changedInfoString = TIM_t("群资料");
        }
        if (changedInfoString == TIM_t("全员禁言状态")) {
          changedInfoString = TIM_t("全员禁言");
          displayMessage = changedValue == false
              ? TIM_t_para("{{option7}} 取消", "$option7 取消")(option7: option7) + changedInfoString
              : TIM_t_para("{{option7}} 开启", "$option7 开启")(option7: option7) + changedInfoString;
        } else {
          displayMessage = TIM_t_para("{{option7}}修改", "$option7修改")(option7: option7) + changedInfoString;
        }
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_QUIT:
        final String? option6 = opUserNickName ?? "";
        displayMessage = TIM_t_para("{{option6}}退出群聊", "$option6退出群聊")(option6: option6);
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_INVITE:
        final option5 = memberList!
            .map(
              (e) => _getMemberNickName(
                e!,
                groupMemberList: groupMemberList,
              ).toString(),
            )
            .join("、");
        displayMessage = '$opUserNickName' + TIM_t_para("邀请{{option5}}加入群组", "邀请$option5加入群组")(option5: option5);
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_KICKED:
        final option4 = memberList!
            .map(
              (e) => _getMemberNickName(
                e!,
                groupMemberList: groupMemberList,
              ).toString(),
            )
            .join("、");
        displayMessage = '$opUserNickName' + TIM_t_para("将{{option4}}踢出群组", "将$option4踢出群组")(option4: option4);
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_JOIN:
        final option3 = memberList!
            .map(
              (e) => _getMemberNickName(
                e!,
                groupMemberList: groupMemberList,
              ).toString(),
            )
            .join("、");
        displayMessage = TIM_t_para("用户{{option3}}加入了群聊", "用户$option3加入了群聊")(option3: option3);
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_MEMBER_INFO_CHANGE:
        displayMessage = groupTipsElem.memberList!.map((e) {
          final changedMember =
              groupTipsElem.memberChangeInfoList!.firstWhere((element) => element!.userID == e!.userID);
          final isMute = changedMember!.muteTime != 0;
          final option2 = _getMemberNickName(
            e!,
            groupMemberList: groupMemberList,
          );
          final displayMessage = isMute ? TIM_t("禁言") : TIM_t("解除禁言");
          return TIM_t_para("{{option2}} 被", "$option2 被")(option2: option2) + displayMessage;
        }).join("、");
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_SET_ADMIN:
        final adminMember = memberList!
            .map(
              (e) => _getMemberNickName(
                e!,
                groupMemberList: groupMemberList,
              ).toString(),
            )
            .join("、");
        final option1 = adminMember;
        displayMessage = '$opUserNickName' + TIM_t_para("将 {{option1}} 设置为管理员", "将 $option1 设置为管理员")(option1: option1);
        break;
      case GroupTipsElemType.V2TIM_GROUP_TIPS_TYPE_CANCEL_ADMIN:
        final adminMember = memberList!
            .map(
              (e) => _getMemberNickName(
                e!,
                groupMemberList: groupMemberList,
              ).toString(),
            )
            .join("、");
        final option1 = adminMember;
        displayMessage = '$opUserNickName' + TIM_t_para("将 {{option1}} 取消管理员", "将 $option1 取消管理员")(option1: option1);
        break;
      default:
        final String option2 = operationType.toString();
        displayMessage = TIM_t_para("系统消息 {{option2}}", "系统消息 $option2")(option2: option2);
        break;
    }
    return displayMessage;
  }

  static String formatVideoTime(int time) {
    List<int> times = [];
    if (time <= 0) return '0:01';
    if (time >= TimeConst.DAY_SEC) return '1d+';
    for (int idx = 0; idx < TimeConst.SEC_SERIES.length; idx++) {
      int sec = TimeConst.SEC_SERIES[idx];
      if (time >= sec) {
        times.add((time / sec).floor());
        time = time % sec;
      } else if (idx > 0) {
        times.add(0);
      }
    }
    times.add(time);
    String formatTime = times[0].toString();
    for (int idx = 1; idx < times.length; idx++) {
      if (times[idx] < 10) {
        formatTime += ':0${times[idx].toString()}';
      } else {
        formatTime += ':${times[idx].toString()}';
      }
    }
    return formatTime;
  }

  static String handleCustomMessageString(V2TimMessage message) {
    return TIM_t("消息");
  }

  static Widget wrapMessageTips(Widget child, TUITheme? theme) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 30),
      child: child,
    );
  }

  static String getAbstractMessageAsync(V2TimMessage message, List<V2TimGroupMemberFullInfo?> groupMemberList) {
    final msgType = message.elemType;
    switch (msgType) {
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return handleCustomMessageString(message);
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return TIM_t("[语音]");
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem!.text as String;
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return TIM_t("[表情]");
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final String? option2 = message.fileElem!.fileName ?? "";
        return TIM_t_para("[文件] {{option2}}", "[文件] $option2")(option2: option2);
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        return TIM_t("群提示");
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return TIM_t("[图片]");
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return TIM_t("[视频]");
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return TIM_t("[位置]");
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return TIM_t("[聊天记录]");
      default:
        return TIM_t("未知消息");
    }
  }

  static V2TimImage? getImageFromImgList(List<V2TimImage?>? list, List<String> order) {
    if (list == null || list.isEmpty) {
      return null;
    }
    try {
      for (final type in order) {
        final sdkType = HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES[type];
        if (sdkType == null) {
          continue;
        }
        for (final image in list) {
          if (image?.type == sdkType) {
            return image;
          }
        }
      }
    } catch (e) {
      outputLogger.i('getImageFromImgList error ${e.toString()}');
    }
    return null;
  }

  static String _normalizeGroupId(String? value) {
    final text = value?.trim() ?? '';
    if (text.startsWith('group_')) {
      return text.substring(6);
    }
    return text;
  }

  static String _normalizeUserId(String? value) {
    final text = value?.trim() ?? '';
    if (text.startsWith('c2c_')) {
      return text.substring(4);
    }
    return text;
  }

  static String? _nameFromGroupMember(V2TimGroupMemberFullInfo? member) {
    if (member == null) {
      return null;
    }
    final name = resolveGroupSenderShowName(
      friendRemark: member.friendRemark,
      nameCard: member.nameCard,
      nickName: member.nickName,
      storeName: DisplayNameStore.instance.c2c(member.userID),
      userID: member.userID,
    );
    return TencentUtils.checkString(name);
  }

  /// 解析消息发送人展示名：备注(含 Store) > 群名片 > 昵称 > 成员/缓存 > sender。
  static String getDisplayName(V2TimMessage message) {
    final sender = TencentUtils.checkString(message.sender) ??
        TencentUtils.checkString(message.userID) ??
        '';
    final fromFields = resolveGroupSenderShowName(
      friendRemark: message.friendRemark,
      nameCard: message.nameCard,
      nickName: message.nickName,
      storeName: sender.isEmpty
          ? null
          : DisplayNameStore.instance.c2c(_normalizeUserId(sender)),
      userID: sender,
    );
    if (fromFields.isNotEmpty && fromFields != sender) {
      return fromFields;
    }
    // 消息字段仅有 UID 或全空时，再查群成员 / Store。
    final groupId = _normalizeGroupId(message.groupID);
    if (groupId.isNotEmpty && sender.isNotEmpty) {
      final fromMember = _nameFromGroupMember(
        GroupMemberStore.instance.memberOf(groupId, sender),
      );
      if (fromMember != null) {
        return fromMember;
      }
    }

    if (sender.isNotEmpty) {
      final fromStore = TencentUtils.checkString(
        DisplayNameStore.instance.c2c(_normalizeUserId(sender)),
      );
      if (fromStore != null &&
          !DisplayNameStore.isRawUserIdDisplayName(sender, fromStore)) {
        return fromStore;
      }
    }

    if (fromFields.isNotEmpty) {
      return fromFields;
    }
    return sender;
  }

  static Future<V2TimValueCallback<V2TimMessage>?> handleMessageError(
      Future<V2TimValueCallback<V2TimMessage>?> fun, BuildContext context) async {
    final res = await fun;
    return handleMessageErrorCode(res, context);
  }

  static V2TimValueCallback<V2TimMessage>? handleMessageErrorCode(
      V2TimValueCallback<V2TimMessage>? sendMsgRes, BuildContext context) {
    if (sendMsgRes == null) return null;

    return sendMsgRes;
  }
}
