import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';
import 'package:tencent_cloud_chat_demo/src/pages/add_friend_page.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/user_profile.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_privacy_guard.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

const String kContactCardBusinessID = "contact_card";

class ContactCardBubbleStyle {
  final Color background;
  final Color? borderColor;
  final double borderWidth;
  final Color primaryTextColor;
  final Color footerTextColor;
  final Color avatarPlaceholderColor;

  const ContactCardBubbleStyle({
    required this.background,
    this.borderColor,
    this.borderWidth = 0,
    required this.primaryTextColor,
    required this.footerTextColor,
    required this.avatarPlaceholderColor,
  });

  Border? get border {
    if (borderColor == null || borderWidth <= 0) {
      return null;
    }
    return Border.all(color: borderColor!, width: borderWidth);
  }

  /// 与文本/通话消息气泡使用同一套主题色。
  static ContactCardBubbleStyle resolve(
    TUITheme theme, {
    required bool isFromSelf,
  }) {
    final background = isFromSelf
        ? (theme.chatMessageItemFromSelfBgColor ??
            theme.lightPrimaryMaterialColor.shade50)
        : (theme.chatMessageItemFromOthersBgColor ??
            theme.weakBackgroundColor ??
            Colors.white);
    final isDarkBubble =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;

    final primaryTextColor = isDarkBubble
        ? (isFromSelf
            ? Colors.white
            : (theme.chatMessageItemTextColor ??
                theme.darkTextColor ??
                Colors.white))
        : (theme.chatMessageItemTextColor ??
            theme.conversationItemTitleTextColor ??
            theme.darkTextColor ??
            Colors.black);

    final footerTextColor = isDarkBubble
        ? (isFromSelf
            ? Colors.white.withValues(alpha: 0.72)
            : (theme.weakTextColor ??
                theme.conversationItemLastMessageTextColor ??
                const Color(0xFF8A8A8A)))
        : (theme.weakTextColor ??
            theme.conversationItemLastMessageTextColor ??
            const Color(0xFF8E8E93));

    final borderColor = !isFromSelf && isDarkBubble
        ? (theme.weakDividerColor ?? const Color(0xFF252525))
        : null;

    return ContactCardBubbleStyle(
      background: background,
      borderColor: borderColor,
      borderWidth: borderColor != null ? 0.5 : 0,
      primaryTextColor: primaryTextColor,
      footerTextColor: footerTextColor,
      avatarPlaceholderColor: isDarkBubble
          ? (theme.weakDividerColor ?? const Color(0xFF2A2A2A))
          : const Color(0xFFE8EBF0),
    );
  }
}

class ContactCardMessage {
  final String businessID;
  final int version;
  final String userID;
  final String nickName;
  final String faceUrl;
  final String selfSignature;
  final bool? allowViaCard;

  const ContactCardMessage({
    required this.businessID,
    required this.version,
    required this.userID,
    required this.nickName,
    required this.faceUrl,
    required this.selfSignature,
    this.allowViaCard,
  });

  factory ContactCardMessage.fromJson(Map json) {
    return ContactCardMessage(
      businessID: json["businessID"] ?? "",
      version: json["version"] ?? 1,
      userID: json["userID"] ?? "",
      nickName: json["nickName"] ?? "",
      faceUrl: json["faceUrl"] ?? "",
      selfSignature: json["selfSignature"] ?? "",
      allowViaCard: json["allowViaCard"] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "businessID": businessID,
      "version": version,
      "userID": userID,
      "nickName": nickName,
      "faceUrl": faceUrl,
      "selfSignature": selfSignature,
      if (allowViaCard != null) "allowViaCard": allowViaCard,
    };
  }
}

Future<bool> resolveContactCardAllowViaCard({
  required String targetUserId,
  bool? embeddedAllowViaCard,
}) async {
  final id = targetUserId.trim();
  if (id.isEmpty) {
    return false;
  }

  try {
    final check = await UserApi.instance.checkAddFriend(
      targetUserId: id,
      channel: AddFriendCheckChannel.card,
    );
    return check.allowed;
  } catch (_) {}

  try {
    final remote = await UserApi.instance.fetchUserPrivacy(id);
    if (remote != null) {
      return remote.allowViaCard;
    }
  } catch (_) {
    // 回退名片内嵌权限
  }

  if (embeddedAllowViaCard != null) {
    return embeddedAllowViaCard;
  }
  return false;
}

Future<void> openContactCardUserPage(
  BuildContext context,
  ContactCardMessage message, {
  String? groupId,
}) async {
  final userID = message.userID.trim();
  if (userID.isEmpty) {
    return;
  }

  if (ProfilePageNav.isSelfUser(userID)) {
    await ProfilePageNav.openMyProfileDetail(context);
    return;
  }

  if (PlatformOfficialAccountService.isPlatformOfficialAccount(userID)) {
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      AppMaterialPageRoute(
        builder: (context) => UserProfile(
          userID: userID,
          addSource: FriendAddSource.card,
        ),
      ),
    );
    return;
  }

  final isFriend = await ProfilePageNav.isFriendUser(userID);
  if (!context.mounted) {
    return;
  }

  final gid = groupId?.trim() ?? '';
  // 群内名片：无论是否好友，看资料都走服务端 can-view。
  if (gid.isNotEmpty) {
    final blockedHint = await GroupPrivacyGuard.blockedGroupProfileHint(
      groupId: gid,
      targetUserId: userID,
    );
    if (blockedHint != null) {
      ToastUtils.toast(blockedHint);
      return;
    }
  }

  if (isFriend) {
    await ProfilePageNav.openUserProfile(
      context,
      userID: userID,
      addSource: FriendAddSource.card,
      groupId: gid.isNotEmpty ? gid : null,
    );
    return;
  }

  final allowViaCard = await resolveContactCardAllowViaCard(
    targetUserId: userID,
    embeddedAllowViaCard: message.allowViaCard,
  );

  if (!allowViaCard) {
    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '对方未开放通过名片添加',
      zhHant: '對方未開放通過名片添加',
      en: 'This user does not allow adds via contact card',
      ja: 'This user does not allow adds via contact card',
      ko: 'This user does not allow adds via contact card',
    ));
    return;
  }

  if (!context.mounted) {
    return;
  }

  final displayName =
      message.nickName.trim().isNotEmpty ? message.nickName.trim() : userID;
  V2TimUserFullInfo? sdkUserInfo;
  final sdkRes =
      await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [userID]);
  if (sdkRes.code == 0 && sdkRes.data != null && sdkRes.data!.isNotEmpty) {
    sdkUserInfo = sdkRes.data!.first;
  }
  final initialInfo = sdkUserInfo ??
      V2TimUserFullInfo(
        userID: userID,
        nickName: displayName,
        faceUrl: message.faceUrl.trim(),
      );

  if (!context.mounted) {
    return;
  }

  await AddFriendPage.open(
    context,
    userID: userID,
    nickname: TencentUtils.checkString(initialInfo.nickName) ?? displayName,
    initialUserInfo: initialInfo,
    addSource: FriendAddSource.card,
    groupId: gid.isNotEmpty ? gid : null,
    fromContactCard: true,
    contactCardAllowViaCard: message.allowViaCard,
  );
}

ContactCardMessage? getContactCardMessage(V2TimCustomElem? customElem) {
  try {
    if (customElem?.data == null || customElem!.data!.isEmpty) {
      return null;
    }
    final customMessage = jsonDecode(customElem.data!);
    final message = ContactCardMessage.fromJson(customMessage);
    if (message.businessID != kContactCardBusinessID) {
      return null;
    }
    return message;
  } catch (_) {
    return null;
  }
}

Future<ContactCardMessage> buildSelfContactCardMessage() async {
  final selfVm = serviceLocator<TUISelfInfoViewModel>();
  final login = selfVm.loginInfo;
  final userId = login?.userID?.trim() ?? '';
  if (userId.isEmpty) {
    throw StateError('not logged in');
  }

  var nickName = TencentUtils.checkString(login?.nickName) ?? userId;
  var faceUrl = TencentUtils.checkString(login?.faceUrl) ?? '';
  var selfSignature = '';

  final sdkRes =
      await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [userId]);
  if (sdkRes.code == 0 && sdkRes.data != null && sdkRes.data!.isNotEmpty) {
    final info = sdkRes.data!.first;
    nickName = TencentUtils.checkString(info.nickName) ?? nickName;
    faceUrl = TencentUtils.checkString(info.faceUrl) ?? faceUrl;
    selfSignature = TencentUtils.checkString(info.selfSignature) ?? '';
  }

  bool? allowViaCard;
  try {
    allowViaCard = (await UserApi.instance.fetchPrivacy()).allowViaCard;
  } catch (_) {
    allowViaCard = null;
  }

  return ContactCardMessage(
    businessID: kContactCardBusinessID,
    version: 1,
    userID: userId,
    nickName: nickName,
    faceUrl: faceUrl,
    selfSignature: selfSignature,
    allowViaCard: allowViaCard,
  );
}

Future<ContactCardMessage> buildContactCardMessageForUser(String userId) async {
  final id = userId.trim();
  if (id.isEmpty) {
    throw StateError('empty userId');
  }

  var nickName = id;
  var faceUrl = '';
  var selfSignature = '';

  final sdkRes =
      await TIMUIKitCore.getSDKInstance().getUsersInfo(userIDList: [id]);
  if (sdkRes.code == 0 && sdkRes.data != null && sdkRes.data!.isNotEmpty) {
    final info = sdkRes.data!.first;
    nickName = TencentUtils.checkString(info.nickName) ?? nickName;
    faceUrl = TencentUtils.checkString(info.faceUrl) ?? faceUrl;
    selfSignature = TencentUtils.checkString(info.selfSignature) ?? '';
  }

  bool? allowViaCard;
  try {
    final selfUserId =
        serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
    if (id == selfUserId) {
      allowViaCard = (await UserApi.instance.fetchPrivacy()).allowViaCard;
    } else {
      final remote = await UserApi.instance.fetchUserPrivacy(id);
      allowViaCard = remote?.allowViaCard;
    }
  } catch (_) {
    allowViaCard = null;
  }

  return ContactCardMessage(
    businessID: kContactCardBusinessID,
    version: 1,
    userID: id,
    nickName: nickName,
    faceUrl: faceUrl,
    selfSignature: selfSignature,
    allowViaCard: allowViaCard,
  );
}

Future<bool> sendContactCardToConversation({
  required ContactCardMessage card,
  required String receiverUserId,
  required String groupId,
  bool enforceCardOwnerPrivacy = false,
}) async {
  final receiver = receiverUserId.trim();
  final group = groupId.trim();
  if (receiver.isEmpty && group.isEmpty) {
    return false;
  }

  if (enforceCardOwnerPrivacy) {
    if (card.allowViaCard == false) {
      return false;
    }
    final allowed = await resolveContactCardAllowViaCard(
      targetUserId: card.userID,
      embeddedAllowViaCard: card.allowViaCard,
    );
    if (!allowed) {
      return false;
    }
  }

  final messageData = jsonEncode(card.toJson());
  final sdk = TIMUIKitCore.getSDKInstance();
  final createRes =
      await sdk.getMessageManager().createCustomMessage(data: messageData);
  final messageID = createRes.data?.id;
  if (createRes.code != 0 || messageID == null || messageID.isEmpty) {
    return false;
  }

  return ChatExternalMessageSender.sendCreatedMessage(
    messageInfo: createRes.data?.messageInfo,
    receiverUserId: receiver,
    groupId: group,
    reason: 'contact_card_share_sent',
  );
}

Future<bool> sendSelfContactCardToConversation({
  required String receiverUserId,
  required String groupId,
}) async {
  final card = await buildSelfContactCardMessage();
  return sendContactCardToConversation(
    card: card,
    receiverUserId: receiverUserId,
    groupId: groupId,
    enforceCardOwnerPrivacy: true,
  );
}
