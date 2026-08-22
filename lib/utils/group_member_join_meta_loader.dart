import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_member_join_meta.dart';

/// 资料页加载「入群时间 / 入群方式」成员记录。
class GroupMemberJoinMetaLoader {
  GroupMemberJoinMetaLoader._();

  /// 可见性不通过时返回 null；可见时返回本地（必要时补拉）记录。
  static Future<GroupMemberRecord?> loadVisible({
    required String groupId,
    required String userId,
  }) async {
    final gid = groupId.trim();
    final uid = ChatIdFormat.rawUserUid(userId);
    if (gid.isEmpty || uid.isEmpty) {
      return null;
    }
    if (!await GroupMemberJoinMeta.canView(groupId: gid)) {
      return null;
    }

    var record = await GroupMemberLocalStore.instance.readRecord(
      groupId: gid,
      userId: uid,
    );
    if (record != null && GroupMemberJoinMeta.hasAnyDisplayRow(record)) {
      return record;
    }

    try {
      // 首屏找不到目标时继续翻页，避免大群成员落在 offset>0。
      var offset = 0;
      const limit = 100;
      GroupMemberRecord? found;
      while (offset < 1000) {
        final page = await MeGroupApi.instance.fetchGroupMembersPage(
          groupId: gid,
          limit: limit,
          offset: offset,
          refresh: offset == 0,
        );
        if (page.items.isNotEmpty) {
          await GroupMemberLocalStore.instance.upsertMany(
            ownerUserId: '',
            groupId: gid,
            records: page.items,
          );
        }
        for (final item in page.items) {
          if (item.userId == uid) {
            found = item;
            break;
          }
        }
        if (found != null) {
          break;
        }
        if (page.items.isEmpty ||
            page.items.length < limit ||
            offset + page.items.length >= page.total) {
          break;
        }
        offset += page.items.length;
      }
      if (found != null) {
        return found;
      }
      record = await GroupMemberLocalStore.instance.readRecord(
        groupId: gid,
        userId: uid,
      );
    } catch (_) {
      // 网络失败时仍返回已有本地记录（可能为空展示）。
    }
    return record;
  }
}
