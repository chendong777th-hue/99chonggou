import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 按群 ID 解析群资料，兼容 Public / Community 等类型。
class GroupLookup {
  GroupLookup._();

  static Future<V2TimGroupInfo?> resolve(
    String groupKey, {
    GroupServices? groupServices,
  }) async {
    final services = groupServices ?? serviceLocator<GroupServices>();
    final candidates = ChatIdFormat.groupIdLookupCandidates(groupKey);
    if (candidates.isEmpty) {
      return null;
    }

    for (final candidate in candidates) {
      final info = await _getGroupsInfo(services, candidate);
      if (info != null) {
        return info;
      }
    }

    final searchKeys = <String>{};
    for (final candidate in candidates) {
      final stripped =
          candidate.startsWith('@') ? candidate.substring(1) : candidate;
      if (stripped.isEmpty || stripped.toUpperCase().contains('TGS#')) {
        continue;
      }
      searchKeys.add(stripped);
    }

    for (final key in searchKeys) {
      final local = await _searchGroupsLocal(key);
      if (local != null) {
        return local;
      }
      final cloud = await _searchGroupsCloud(key);
      if (cloud != null) {
        return cloud;
      }
    }

    return null;
  }

  static Future<V2TimGroupInfo?> _getGroupsInfo(
    GroupServices services,
    String groupID,
  ) async {
    final res = await services.getGroupsInfo(groupIDList: [groupID]);
    if (res == null) {
      return null;
    }
    for (final item in res) {
      if (item.resultCode == 0 && item.groupInfo != null) {
        final id = item.groupInfo!.groupID.trim();
        if (id.isNotEmpty) {
          return item.groupInfo;
        }
      }
    }
    return null;
  }

  /// 本地群搜索。勿用 [searchGroupByID]：SDK 实际返回 List，会触发类型转换异常。
  static Future<V2TimGroupInfo?> _searchGroupsLocal(String groupID) async {
    final keyword = groupID.trim();
    if (keyword.isEmpty) {
      return null;
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getGroupManager()
          .searchGroups(
            searchParam: V2TimGroupSearchParam(
              keywordList: [keyword],
              isSearchGroupID: true,
              isSearchGroupName: false,
            ),
          );
      if (res.code == 0) {
        return _pickMatchingGroup(res.data, keyword);
      }
    } catch (_) {}
    return null;
  }

  static Future<V2TimGroupInfo?> _searchGroupsCloud(String groupID) async {
    final keyword = groupID.trim();
    if (keyword.isEmpty) {
      return null;
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getGroupManager()
          .searchCloudGroups(
            searchParam: V2TimGroupSearchParam(
              keywordList: [keyword],
              isSearchGroupID: true,
              isSearchGroupName: false,
            ),
          );
      if (res.code == 0) {
        return _pickMatchingGroup(res.data?.groupList, keyword);
      }
    } catch (_) {}
    return null;
  }

  static V2TimGroupInfo? _pickMatchingGroup(
    List<V2TimGroupInfo>? groups,
    String keyword,
  ) {
    if (groups == null || groups.isEmpty) {
      return null;
    }
    final normalizedKeyword = keyword.trim().toLowerCase();
    for (final group in groups) {
      final id = group.groupID.trim();
      if (id.isEmpty) {
        continue;
      }
      if (id.toLowerCase() == normalizedKeyword) {
        return group;
      }
      final short = ChatIdFormat.communityShortSuffix(id);
      if (short != null && short.toLowerCase() == normalizedKeyword) {
        return group;
      }
    }
    final fallback = groups.first;
    return fallback.groupID.trim().isNotEmpty ? fallback : null;
  }
}
