import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 缓存离线推送需要同步读取的身份信息。
///
/// `MessageOfflinePush.build` 是同步回调（见 chat.dart 的 offlinePushInfo），
/// 无法在其中 await 网络请求，因此发送方自己的昵称/头像必须预先缓存。
class PushIdentityCache {
  PushIdentityCache._();

  static final PushIdentityCache instance = PushIdentityCache._();

  String? selfNickName;
  String? selfFaceUrl;

  /// 同步读取当前用户头像（缓存 → IM self 资料）。
  String selfFaceUrlOrBest() {
    final cached = resolvePushAvatarUrl(selfFaceUrl);
    if (cached.isNotEmpty) {
      return cached;
    }
    return resolvePushAvatarUrl(UserAvatarHelper.currentSelfFaceUrl());
  }

  /// 登录成功后调用，拉取并缓存当前登录用户的昵称与头像。
  Future<void> refreshSelf() async {
    try {
      final loginRes = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
      final userId = loginRes.data?.trim();
      if (userId == null || userId.isEmpty) {
        return;
      }
      final res = await TencentImSDKPlugin.v2TIMManager
          .getUsersInfo(userIDList: [userId]);
      final list = res.data;
      if (list != null && list.isNotEmpty) {
        final info = list.first;
        final nick = info.nickName?.trim();
        final face = info.faceUrl?.trim();
        if (nick != null && nick.isNotEmpty) {
          selfNickName = nick;
        }
        if (face != null && face.isNotEmpty) {
          selfFaceUrl = resolvePushAvatarUrl(face);
        }
      }
    } catch (_) {}

    final liveFace = resolvePushAvatarUrl(UserAvatarHelper.currentSelfFaceUrl());
    if (liveFace.isNotEmpty) {
      selfFaceUrl = liveFace;
    }

    try {
      final me = await AuthApi.instance.fetchMe();
      final backendFace = resolvePushAvatarUrl(me.avatarUrl);
      if (backendFace.isNotEmpty) {
        selfFaceUrl = backendFace;
      }
      final backendNick = me.nickname.trim();
      if (backendNick.isNotEmpty) {
        selfNickName = backendNick;
      }
    } catch (_) {}
  }

  void clear() {
    selfNickName = null;
    selfFaceUrl = null;
  }

  /// 群推送展示：本地群 Entity 优先，会话行仅补空字段。
  @visibleForTesting
  static ({String? showName, String? faceUrl}) mergeGroupPushIdentity({
    String? conversationShowName,
    String? conversationFaceUrl,
    String? localGroupName,
    String? localGroupAvatarUrl,
    String? groupId,
  }) {
    final localName = (localGroupName ?? '').trim();
    final usableLocalName = localName.isNotEmpty &&
            !GroupDisplayResolver.looksLikeGroupIdLabel(
              localName,
              groupId: groupId,
            )
        ? localName
        : '';
    final localFace = resolvePushAvatarUrl(localGroupAvatarUrl);
    final convName = (conversationShowName ?? '').trim();
    final usableConvName = convName.isNotEmpty &&
            !GroupDisplayResolver.looksLikeGroupIdLabel(
              convName,
              groupId: groupId,
            )
        ? convName
        : '';
    final convFace = resolvePushAvatarUrl(conversationFaceUrl);

    final showName =
        usableLocalName.isNotEmpty ? usableLocalName : usableConvName;
    final faceUrl = localFace.isNotEmpty ? localFace : convFace;
    if (showName.isEmpty && faceUrl.isEmpty) {
      return (showName: null, faceUrl: null);
    }
    return (
      showName: showName.isNotEmpty ? showName : null,
      faceUrl: faceUrl.isNotEmpty ? faceUrl : null,
    );
  }

  /// 同步查询群聊推送用的展示名与头像。
  /// 优先 [GroupLocalStore] / [DisplayNameStore]，会话模型仅补缺。
  ({String? showName, String? faceUrl})? lookupConversation(
    String? conversationID, {
    String? groupId,
  }) {
    if (conversationID == null || conversationID.isEmpty) {
      return null;
    }

    String? conversationShowName;
    String? conversationFaceUrl;
    try {
      final model = serviceLocator<TUIConversationViewModel>();
      for (final conv in model.conversationList) {
        if (conv?.conversationID == conversationID) {
          conversationShowName = conv?.showName;
          conversationFaceUrl = conv?.faceUrl;
          break;
        }
      }
    } catch (_) {}

    final candidates = <String>{
      if (groupId != null && groupId.trim().isNotEmpty)
        ChatIdFormat.normalizeGroupId(groupId),
      if (conversationID.startsWith('group_'))
        ChatIdFormat.normalizeGroupId(
          conversationID.substring('group_'.length),
        ),
    };

    String localName = '';
    String localAvatar = '';
    String resolvedGroupId = '';
    for (final id in candidates) {
      if (id.isEmpty) {
        continue;
      }
      resolvedGroupId = id;
      try {
        final fromStore = DisplayNameStore.instance.group(id)?.trim() ?? '';
        if (fromStore.isNotEmpty) {
          localName = fromStore;
        }
      } catch (_) {}
      final record = GroupLocalStore.instance.readCached(groupId: id);
      final recordName = record?.groupName.trim() ?? '';
      if (localName.isEmpty && recordName.isNotEmpty) {
        localName = recordName;
      }
      final recordAvatar = record?.avatarUrl.trim() ?? '';
      if (localAvatar.isEmpty && recordAvatar.isNotEmpty) {
        localAvatar = recordAvatar;
      }
      if (localName.isNotEmpty && localAvatar.isNotEmpty) {
        break;
      }
    }

    final merged = mergeGroupPushIdentity(
      conversationShowName: conversationShowName,
      conversationFaceUrl: conversationFaceUrl,
      localGroupName: localName,
      localGroupAvatarUrl: localAvatar,
      groupId: resolvedGroupId.isNotEmpty ? resolvedGroupId : groupId,
    );
    if (merged.showName == null && merged.faceUrl == null) {
      return null;
    }
    return merged;
  }

  static String resolvePushAvatarUrl(String? raw) {
    final usable = UserAvatarHelper.usableAvatarOrEmpty(raw);
    if (usable.isEmpty) {
      return '';
    }
    return MediaUrlResolver.resolve(usable) ?? usable;
  }
}
