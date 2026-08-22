import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
/// UI 统一读取群展示字段（REST 本地库为唯一数据源）。
class GroupInfoResolver {
  GroupInfoResolver._();

  static final GroupInfoResolver instance = GroupInfoResolver._();

  Future<MeGroupRecord?> readGroup(String groupId, {String? ownerUserId}) {
    return GroupLocalStore.instance.read(
      groupId: groupId,
      ownerUserId: ownerUserId,
    );
  }

  Future<String> groupName(String groupId, {String fallback = ''}) async {
    final record = await readGroup(groupId);
    final name = record?.groupName.trim() ?? '';
    return name.isNotEmpty ? name : fallback;
  }

  Future<String> displayAlias(String groupId) async {
    final record = await readGroup(groupId);
    return ChatIdFormat.displayGroupAlias(
      record?.displayAlias,
      groupIdFallback: record?.groupId ?? groupId,
    );
  }

  Future<String> avatarUrl(String groupId, {String fallback = ''}) async {
    final record = await readGroup(groupId);
    final url = record?.avatarUrl.trim() ?? '';
    return url.isNotEmpty ? url : fallback;
  }

  Future<String> notice(String groupId) async {
    final record = await readGroup(groupId);
    return record?.notice.trim() ?? '';
  }

  Future<int?> memberCount(String groupId) async {
    final record = await readGroup(groupId);
    if (record == null) {
      return null;
    }
    return record.memberCount;
  }

  Future<int?> myRole(String groupId) async {
    final record = await readGroup(groupId);
    return record?.myRole;
  }

  Future<String> myNameCard(String groupId) async {
    final record = await readGroup(groupId);
    return record?.myNameCard.trim() ?? '';
  }
}
