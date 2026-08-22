import 'package:tencent_cloud_chat_demo/src/services/archived_conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_background_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_prefs.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 注销账号时按 owner 清除 App 本地磁盘数据（多账号行隔离删除）。
///
/// 常规登出不得调用本类；常规登出只卸内存，保留 SQLite / prefs。
class LocalAccountDataPurge {
  LocalAccountDataPurge._();

  static final LocalAccountDataPurge instance = LocalAccountDataPurge._();

  /// 在 clearToken / IM logout 之前调用，确保仍能解析到 [ownerUserId]。
  Future<void> purgeOwnerDisk(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return;
    }

    await _safe(() => ConversationLocalStore.instance.clearForOwner(owner));
    await _safe(() => FriendLocalStore.instance.clearForOwner(owner));
    await _safe(() => UserProfileLocalStore.instance.clearForOwner(owner));
    await _safe(() => GroupLocalStore.instance.clearForOwner(owner));
    await _safe(() => GroupMemberLocalStore.instance.clearForOwner(owner));
    await _safe(() => MessageMediaMetadataStore.instance.clearForOwner(owner));
    await _safe(() => PushTokenUploadLocalStore.instance.clearForOwner(owner));
    await _safe(() => PrivilegedGameUserStore.instance.clearOwner(owner));
    await _safe(() => SangongMyConfigStore.instance.clearOwner(owner));
    await _safe(() => ConversationFolderStore.instance.clearForOwner(owner));
    await _safe(() => ConversationPinSyncService.instance.clearForOwner(owner));
    await _safe(
      () => ArchivedConversationSyncService.instance.clearForOwner(owner),
    );
    await _safe(() => ContactSocialCacheStore.clearAllForOwner(owner));
    await _safe(() => RedPacketLocalStore.instance.clearForOwner(owner));
    await _safe(() => MomentsLocalStore.instance.clearForOwner(owner));
    await _safe(() => MomentsLocalPrefs.clearForOwner(owner));
    await _safe(() => MomentsStore.clearDraftForOwner(owner));
    await _safe(() => ChatBackgroundService.instance.clearForOwner(owner));
    await _safe(() => GroupNoticeUnreadService.instance.clearForOwner(owner));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}
