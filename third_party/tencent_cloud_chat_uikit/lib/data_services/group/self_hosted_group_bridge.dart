import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart'
    show SelfHostedIdSearchPage;

typedef SelfHostedJoinedGroupListLoader =
    Future<List<V2TimGroupInfo>> Function();

typedef SelfHostedGroupLocalSearcher = Future<SelfHostedIdSearchPage> Function({
  required String keyword,
  int limit,
  String? cursor,
});
typedef SelfHostedGroupHydrator = Future<List<V2TimGroupInfo>> Function(
  List<String> groupIds,
);

typedef SelfHostedGroupsInfoLoader = Future<List<V2TimGroupInfoResult>> Function(
  List<String> groupIDList,
);

typedef SelfHostedGroupMemberListLoader =
    Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> Function({
  required String groupID,
  required int count,
  required String nextSeq,
});

typedef SelfHostedCachedGroupMemberListLoader =
    Future<List<V2TimGroupMemberFullInfo>> Function(String groupID);

typedef SelfHostedGroupMembersInfoLoader =
    Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>> Function({
  required String groupID,
  required List<String> memberList,
});

typedef SelfHostedGroupInfoUpdater = Future<V2TimCallback> Function({
  required V2TimGroupInfo info,
});

typedef SelfHostedGroupMemberInfoUpdater = Future<V2TimCallback> Function({
  required String groupID,
  required String userID,
  String? nameCard,
});

typedef SelfHostedGroupSelfLeftHandler = Future<void> Function(String groupID);

typedef SelfHostedGroupLeaveHandler = Future<V2TimCallback> Function(String groupID);

typedef SelfHostedGroupDismissHandler = Future<V2TimCallback> Function(String groupID);

typedef SelfHostedGroupKickHandler = Future<V2TimCallback> Function({
  required String groupID,
  required List<String> memberList,
});

typedef SelfHostedGroupMemberRoleHandler = Future<V2TimCallback> Function({
  required String groupID,
  required String userID,
  required int role,
});

typedef SelfHostedGroupMemberRolesHandler = Future<V2TimCallback> Function({
  required String groupID,
  required List<String> userIDs,
  required int role,
});

typedef SelfHostedGroupTransferOwnerHandler = Future<V2TimCallback> Function({
  required String groupID,
  required String userID,
});

typedef SelfHostedGroupMuteMemberHandler = Future<V2TimCallback> Function({
  required String groupID,
  required String userID,
  required int seconds,
});

/// Bridge from UIKit to 99chat-server self-hosted group profile APIs.
class SelfHostedGroupBridge {
  SelfHostedGroupBridge._();

  static SelfHostedJoinedGroupListLoader? _loadJoinedGroupList;
  static SelfHostedGroupsInfoLoader? _loadGroupsInfo;
  static SelfHostedGroupMemberListLoader? _loadGroupMemberList;
  static SelfHostedCachedGroupMemberListLoader? _loadCachedGroupMemberList;
  static SelfHostedGroupMembersInfoLoader? _loadGroupMembersInfo;
  static SelfHostedGroupInfoUpdater? _updateGroupInfo;
  static SelfHostedGroupMemberInfoUpdater? _updateGroupMemberInfo;
  static SelfHostedGroupSelfLeftHandler? _onSelfLeftGroup;
  static SelfHostedGroupLeaveHandler? _leaveGroup;
  static SelfHostedGroupDismissHandler? _dismissGroup;
  static SelfHostedGroupKickHandler? _kickGroupMember;
  static SelfHostedGroupMemberRoleHandler? _setGroupMemberRole;
  static SelfHostedGroupMemberRolesHandler? _setGroupMemberRoles;
  static SelfHostedGroupTransferOwnerHandler? _transferGroupOwner;
  static SelfHostedGroupMuteMemberHandler? _muteGroupMember;
  static SelfHostedGroupLocalSearcher? _searchGroupsLocal;
  static SelfHostedGroupHydrator? _hydrateGroups;

  static bool get enabled => _loadGroupsInfo != null;

  static bool get localSearchEnabled => _searchGroupsLocal != null;

  static bool get governanceEnabled =>
      _leaveGroup != null && _dismissGroup != null;

  static void configure({
    SelfHostedJoinedGroupListLoader? loadJoinedGroupList,
    SelfHostedGroupsInfoLoader? loadGroupsInfo,
    SelfHostedGroupMemberListLoader? loadGroupMemberList,
    SelfHostedCachedGroupMemberListLoader? loadCachedGroupMemberList,
    SelfHostedGroupMembersInfoLoader? loadGroupMembersInfo,
    SelfHostedGroupInfoUpdater? updateGroupInfo,
    SelfHostedGroupMemberInfoUpdater? updateGroupMemberInfo,
    SelfHostedGroupSelfLeftHandler? onSelfLeftGroup,
    SelfHostedGroupLeaveHandler? leaveGroup,
    SelfHostedGroupDismissHandler? dismissGroup,
    SelfHostedGroupKickHandler? kickGroupMember,
    SelfHostedGroupMemberRoleHandler? setGroupMemberRole,
    SelfHostedGroupMemberRolesHandler? setGroupMemberRoles,
    SelfHostedGroupTransferOwnerHandler? transferGroupOwner,
    SelfHostedGroupMuteMemberHandler? muteGroupMember,
    SelfHostedGroupLocalSearcher? searchGroupsLocal,
    SelfHostedGroupHydrator? hydrateGroups,
  }) {
    _loadJoinedGroupList = loadJoinedGroupList;
    _loadGroupsInfo = loadGroupsInfo;
    _loadGroupMemberList = loadGroupMemberList;
    _loadCachedGroupMemberList = loadCachedGroupMemberList;
    _loadGroupMembersInfo = loadGroupMembersInfo;
    _updateGroupInfo = updateGroupInfo;
    _updateGroupMemberInfo = updateGroupMemberInfo;
    _onSelfLeftGroup = onSelfLeftGroup;
    _leaveGroup = leaveGroup;
    _dismissGroup = dismissGroup;
    _kickGroupMember = kickGroupMember;
    _setGroupMemberRole = setGroupMemberRole;
    _setGroupMemberRoles = setGroupMemberRoles;
    _transferGroupOwner = transferGroupOwner;
    _muteGroupMember = muteGroupMember;
    _searchGroupsLocal = searchGroupsLocal;
    _hydrateGroups = hydrateGroups;
  }

  static void clear() {
    _loadJoinedGroupList = null;
    _loadGroupsInfo = null;
    _loadGroupMemberList = null;
    _loadCachedGroupMemberList = null;
    _loadGroupMembersInfo = null;
    _updateGroupInfo = null;
    _updateGroupMemberInfo = null;
    _onSelfLeftGroup = null;
    _leaveGroup = null;
    _dismissGroup = null;
    _kickGroupMember = null;
    _setGroupMemberRole = null;
    _setGroupMemberRoles = null;
    _transferGroupOwner = null;
    _muteGroupMember = null;
    _searchGroupsLocal = null;
    _hydrateGroups = null;
  }

  static Future<SelfHostedIdSearchPage> searchGroupsLocal({
    required String keyword,
    int limit = 80,
    String? cursor,
  }) async {
    final searcher = _searchGroupsLocal;
    if (searcher == null) {
      return SelfHostedIdSearchPage.empty;
    }
    return searcher(keyword: keyword, limit: limit, cursor: cursor);
  }

  static Future<List<V2TimGroupInfo>> hydrateGroups(
    List<String> groupIds,
  ) async {
    final hydrator = _hydrateGroups;
    if (hydrator == null || groupIds.isEmpty) {
      return const <V2TimGroupInfo>[];
    }
    return hydrator(groupIds);
  }

  static Future<List<V2TimGroupInfo>> loadJoinedGroupList() async {
    final loader = _loadJoinedGroupList;
    if (loader == null) {
      return const <V2TimGroupInfo>[];
    }
    return loader();
  }

  static Future<List<V2TimGroupInfoResult>> loadGroupsInfo(
    List<String> groupIDList,
  ) async {
    final loader = _loadGroupsInfo;
    if (loader == null) {
      return const <V2TimGroupInfoResult>[];
    }
    return loader(groupIDList);
  }

  static Future<V2TimValueCallback<V2TimGroupMemberInfoResult>> loadGroupMemberList({
    required String groupID,
    required int count,
    required String nextSeq,
  }) async {
    final loader = _loadGroupMemberList;
    if (loader == null) {
      return V2TimValueCallback(
        code: -1,
        desc: 'BRIDGE_DISABLED',
        data: V2TimGroupMemberInfoResult(nextSeq: '0'),
      );
    }
    return loader(groupID: groupID, count: count, nextSeq: nextSeq);
  }

  static Future<List<V2TimGroupMemberFullInfo>> loadCachedGroupMemberList(
    String groupID,
  ) async {
    final loader = _loadCachedGroupMemberList;
    if (loader == null) {
      return const <V2TimGroupMemberFullInfo>[];
    }
    final id = groupID.trim();
    if (id.isEmpty) {
      return const <V2TimGroupMemberFullInfo>[];
    }
    return loader(id);
  }

  static Future<V2TimValueCallback<List<V2TimGroupMemberFullInfo>>>
      loadGroupMembersInfo({
    required String groupID,
    required List<String> memberList,
  }) async {
    final loader = _loadGroupMembersInfo;
    if (loader == null) {
      return V2TimValueCallback(
        code: -1,
        desc: 'BRIDGE_DISABLED',
        data: <V2TimGroupMemberFullInfo>[],
      );
    }
    return loader(groupID: groupID, memberList: memberList);
  }

  static Future<V2TimCallback> updateGroupInfo({
    required V2TimGroupInfo info,
  }) async {
    final updater = _updateGroupInfo;
    if (updater == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return updater(info: info);
  }

  static Future<V2TimCallback> updateGroupMemberInfo({
    required String groupID,
    required String userID,
    String? nameCard,
  }) async {
    final updater = _updateGroupMemberInfo;
    if (updater == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return updater(groupID: groupID, userID: userID, nameCard: nameCard);
  }

  static Future<void> notifySelfLeftGroup(String groupID) async {
    final handler = _onSelfLeftGroup;
    if (handler == null) {
      return;
    }
    final id = groupID.trim();
    if (id.isEmpty) {
      return;
    }
    await handler(id);
  }

  static Future<V2TimCallback> leaveGroup(String groupID) async {
    final handler = _leaveGroup;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(groupID.trim());
  }

  static Future<V2TimCallback> dismissGroup(String groupID) async {
    final handler = _dismissGroup;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(groupID.trim());
  }

  static Future<V2TimCallback> kickGroupMember({
    required String groupID,
    required List<String> memberList,
  }) async {
    final handler = _kickGroupMember;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(groupID: groupID.trim(), memberList: memberList);
  }

  static Future<V2TimCallback> setGroupMemberRole({
    required String groupID,
    required String userID,
    required int role,
  }) async {
    final batch = _setGroupMemberRoles;
    if (batch != null) {
      return batch(
        groupID: groupID.trim(),
        userIDs: <String>[userID.trim()],
        role: role,
      );
    }
    final handler = _setGroupMemberRole;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(groupID: groupID.trim(), userID: userID.trim(), role: role);
  }

  static Future<V2TimCallback> setGroupMemberRoles({
    required String groupID,
    required List<String> userIDs,
    required int role,
  }) async {
    final batch = _setGroupMemberRoles;
    if (batch != null) {
      return batch(
        groupID: groupID.trim(),
        userIDs: userIDs,
        role: role,
      );
    }
    final handler = _setGroupMemberRole;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    V2TimCallback? last;
    for (final userID in userIDs) {
      final id = userID.trim();
      if (id.isEmpty) continue;
      last = await handler(groupID: groupID.trim(), userID: id, role: role);
      if (last.code != 0) {
        return last;
      }
    }
    return last ?? V2TimCallback(code: -1, desc: 'INVALID_INPUT');
  }

  static Future<V2TimCallback> transferGroupOwner({
    required String groupID,
    required String userID,
  }) async {
    final handler = _transferGroupOwner;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(groupID: groupID.trim(), userID: userID.trim());
  }

  static Future<V2TimCallback> muteGroupMember({
    required String groupID,
    required String userID,
    required int seconds,
  }) async {
    final handler = _muteGroupMember;
    if (handler == null) {
      return V2TimCallback(code: -1, desc: 'BRIDGE_DISABLED');
    }
    return handler(
      groupID: groupID.trim(),
      userID: userID.trim(),
      seconds: seconds,
    );
  }
}
